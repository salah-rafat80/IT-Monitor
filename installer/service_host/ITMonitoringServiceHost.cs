using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;

namespace ITNetworkMonitor.ServiceHost
{
    public class ITMonitoringService : ServiceBase
    {
        private const string ServiceNameConst = "ITNetworkMonitorService";
        private const string DisplayNameConst = "IT Network Monitoring Service";
        private const string DescriptionConst = "Authoritative background network monitoring service for IT Network Monitor.";

        private Process _childProcess;
        private Thread _monitorThread;
        private volatile bool _isStopping = false;
        private string _logFilePath;
        private object _logLock = new object();

        public ITMonitoringService()
        {
            this.ServiceName = ServiceNameConst;
            this.CanStop = true;
            this.CanShutdown = true;
            this.CanPauseAndContinue = false;
            this.AutoLog = true;

            InitLogPath();
        }

        private void InitLogPath()
        {
            try
            {
                string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
                string logDir = Path.Combine(programData, "ITNetworkMonitor", "logs");
                if (!Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }
                _logFilePath = Path.Combine(logDir, "service_host.log");
            }
            catch
            {
                // Fallback to local directory
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string localLogDir = Path.Combine(baseDir, "logs");
                if (!Directory.Exists(localLogDir))
                {
                    Directory.CreateDirectory(localLogDir);
                }
                _logFilePath = Path.Combine(localLogDir, "service_host.log");
            }
        }

        private void Log(string message)
        {
            try
            {
                lock (_logLock)
                {
                    string entry = string.Format("[{0:yyyy-MM-dd HH:mm:ss}] [ServiceHost] {1}{2}", DateTime.Now, message, Environment.NewLine);
                    Console.Write(entry);
                    if (!string.IsNullOrEmpty(_logFilePath))
                    {
                        File.AppendAllText(_logFilePath, entry);
                    }
                }
            }
            catch { }
        }

        protected override void OnStart(string[] args)
        {
            _isStopping = false;
            Log("Windows ServiceControlManager signaled OnStart. Initializing supervisor...");

            _monitorThread = new Thread(SupervisorLoop);
            _monitorThread.IsBackground = true;
            _monitorThread.Start();

            Log("Service host started successfully. SCM handshake completed.");
        }

        private void SupervisorLoop()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            EnsureTlsCredentials(baseDir);

            string exePath = Path.Combine(baseDir, "it_monitoring_service.exe");

            if (!File.Exists(exePath))
            {
                // Check if in parent directory
                string parentService = Path.GetFullPath(Path.Combine(baseDir, "..", "it_monitoring_service.exe"));
                if (File.Exists(parentService))
                {
                    exePath = parentService;
                }
                else
                {
                    // Fallback to it_network_monitor.exe if it_monitoring_service.exe is not present
                    string clientExe = Path.Combine(baseDir, "it_network_monitor.exe");
                    if (File.Exists(clientExe))
                    {
                        exePath = clientExe;
                    }
                    else
                    {
                        string parentClient = Path.GetFullPath(Path.Combine(baseDir, "..", "it_network_monitor.exe"));
                        if (File.Exists(parentClient))
                        {
                            exePath = parentClient;
                        }
                    }
                }
            }

            if (!File.Exists(exePath))
            {
                Log(string.Format("FATAL: Target monitoring service executable not found at: {0}", exePath));
                return;
            }

            int failureStreak = 0;
            const int maxImmediateFailures = 5;

            while (!_isStopping)
            {
                try
                {
                    Log(string.Format("Launching monitoring engine: {0} --service", exePath));

                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = exePath;
                    psi.Arguments = "--service";
                    psi.WorkingDirectory = Path.GetDirectoryName(exePath);
                    psi.UseShellExecute = false;
                    psi.CreateNoWindow = true;
                    psi.RedirectStandardOutput = true;
                    psi.RedirectStandardError = true;

                    _childProcess = new Process();
                    _childProcess.StartInfo = psi;

                    _childProcess.OutputDataReceived += (s, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            Log(string.Format("[Engine Stdout] {0}", e.Data));
                        }
                    };

                    _childProcess.ErrorDataReceived += (s, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            Log(string.Format("[Engine Stderr] {0}", e.Data));
                        }
                    };

                    DateTime startTime = DateTime.Now;
                    _childProcess.Start();
                    _childProcess.BeginOutputReadLine();
                    _childProcess.BeginErrorReadLine();

                    Log(string.Format("Monitoring process started with PID: {0}", _childProcess.Id));

                    _childProcess.WaitForExit();

                    int exitCode = _childProcess.ExitCode;
                    TimeSpan runDuration = DateTime.Now - startTime;
                    Log(string.Format("Monitoring process exited with code {0} after running for {1}", exitCode, runDuration));

                    if (_isStopping)
                    {
                        break;
                    }

                    // Process crashed or terminated unexpectedly
                    if (runDuration.TotalSeconds < 10)
                    {
                        failureStreak++;
                    }
                    else
                    {
                        failureStreak = 0; // Reset streak if process ran stably for a while
                    }

                    if (failureStreak >= maxImmediateFailures)
                    {
                        Log("Repeated rapid failures detected. Sleeping for 30 seconds before retry...");
                        Thread.Sleep(30000);
                        failureStreak = 0;
                    }
                    else
                    {
                        Log("Restarting monitoring process in 5 seconds...");
                        Thread.Sleep(5000);
                    }
                }
                catch (Exception ex)
                {
                    Log(string.Format("Exception in supervisor loop: {0}", ex.Message));
                    if (!_isStopping)
                    {
                        Thread.Sleep(5000);
                    }
                }
            }
        }

        private void EnsureTlsCredentials(string baseDir)
        {
            try
            {
                string scriptPath = Path.Combine(baseDir, "provision_tls_certificate.ps1");
                if (!File.Exists(scriptPath))
                {
                    string parentScript = Path.GetFullPath(Path.Combine(baseDir, "..", "installer", "provision_tls_certificate.ps1"));
                    if (File.Exists(parentScript))
                    {
                        scriptPath = parentScript;
                    }
                }

                if (File.Exists(scriptPath))
                {
                    Log(string.Format("Validating TLS credentials with: {0}", scriptPath));
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = "powershell.exe";
                    psi.Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -AddToTrustedRoot", scriptPath);
                    psi.WorkingDirectory = Path.GetDirectoryName(scriptPath);
                    psi.UseShellExecute = false;
                    psi.CreateNoWindow = true;
                    psi.RedirectStandardOutput = true;
                    psi.RedirectStandardError = true;

                    using (Process p = Process.Start(psi))
                    {
                        p.WaitForExit(30000);
                        Log(string.Format("TLS credentials verification script exited with code {0}", p.ExitCode));
                    }
                }
            }
            catch (Exception ex)
            {
                Log(string.Format("Notice: Could not run TLS credentials check: {0}", ex.Message));
            }
        }

        protected override void OnStop()
        {
            _isStopping = true;
            Log("Windows ServiceControlManager signaled OnStop. Terminating monitoring process gracefully...");

            try
            {
                if (_childProcess != null && !_childProcess.HasExited)
                {
                    // Attempt graceful stop
                    _childProcess.CloseMainWindow();
                    if (!_childProcess.WaitForExit(5000))
                    {
                        Log("Process did not exit within 5 seconds. Forcing termination...");
                        _childProcess.Kill();
                        _childProcess.WaitForExit(3000);
                    }
                }
            }
            catch (Exception ex)
            {
                Log(string.Format("Error stopping child process: {0}", ex.Message));
            }

            Log("Service host stopped cleanly.");
        }

        protected override void OnShutdown()
        {
            Log("Windows system shutdown detected.");
            OnStop();
            base.OnShutdown();
        }

        public void RunInteractive()
        {
            Console.WriteLine("=================================================================");
            Console.WriteLine(" IT Network Monitor - Windows Service Host (Console Debug Mode)");
            Console.WriteLine("=================================================================");
            Console.WriteLine("Press Ctrl+C to stop.\n");

            OnStart(new string[0]);

            AutoResetEvent exitEvent = new AutoResetEvent(false);
            Console.CancelKeyPress += (s, e) =>
            {
                e.Cancel = true;
                exitEvent.Set();
            };

            exitEvent.WaitOne();

            OnStop();
        }

        public static int Main(string[] args)
        {
            string hostExePath = Process.GetCurrentProcess().MainModule.FileName;

            if (args.Length > 0)
            {
                string cmd = args[0].ToLowerInvariant();

                if (cmd == "--install" || cmd == "/install" || cmd == "-i")
                {
                    return InstallService(hostExePath);
                }
                if (cmd == "--uninstall" || cmd == "/uninstall" || cmd == "-u")
                {
                    return UninstallService();
                }
                if (cmd == "--start" || cmd == "/start")
                {
                    return StartServiceCommand();
                }
                if (cmd == "--stop" || cmd == "/stop")
                {
                    return StopServiceCommand();
                }
                if (cmd == "--status" || cmd == "/status")
                {
                    return StatusServiceCommand();
                }
                if (cmd == "--run" || cmd == "/run" || cmd == "-r")
                {
                    ITMonitoringService svc = new ITMonitoringService();
                    svc.RunInteractive();
                    return 0;
                }
            }

            // Normal SCM Service launch
            if (Environment.UserInteractive)
            {
                Console.WriteLine("IT Network Monitor Service Host");
                Console.WriteLine("Usage:");
                Console.WriteLine("  it_service_host.exe --install    : Register Windows Service in services.msc");
                Console.WriteLine("  it_service_host.exe --uninstall  : Remove Windows Service");
                Console.WriteLine("  it_service_host.exe --start      : Start Windows Service");
                Console.WriteLine("  it_service_host.exe --stop       : Stop Windows Service");
                Console.WriteLine("  it_service_host.exe --status     : Query Service status");
                Console.WriteLine("  it_service_host.exe --run        : Run in interactive console mode");
                return 0;
            }

            ServiceBase.Run(new ITMonitoringService());
            return 0;
        }

        private static int InstallService(string exePath)
        {
            Console.WriteLine("Registering IT Network Monitor native Windows Service...");

            // 1. sc.exe create
            string binPathArg = string.Format("\"{0}\"", exePath);
            int createRes = RunProcess("sc.exe", string.Format("create {0} binPath= \"{1}\" start= auto obj= LocalSystem displayName= \"{2}\"", ServiceNameConst, binPathArg, DisplayNameConst));
            if (createRes != 0)
            {
                Console.WriteLine("ERROR: sc.exe create failed with code " + createRes);
                return createRes;
            }

            // 2. sc.exe description
            RunProcess("sc.exe", string.Format("description {0} \"{1}\"", ServiceNameConst, DescriptionConst));

            // 3. sc.exe failure recovery configuration
            // Reset failure counter after 86400 seconds (1 day)
            // 1st failure: restart after 5s
            // 2nd failure: restart after 10s
            // subsequent: restart after 60s
            RunProcess("sc.exe", string.Format("failure {0} reset= 86400 actions= restart/5000/restart/10000/restart/60000", ServiceNameConst));

            Console.WriteLine("[SUCCESS] Service registered with SCM. Auto-start on boot configured.");
            return 0;
        }

        private static int UninstallService()
        {
            Console.WriteLine("Stopping and removing IT Network Monitor Windows Service...");
            RunProcess("sc.exe", string.Format("stop {0}", ServiceNameConst));
            Thread.Sleep(2000);
            int res = RunProcess("sc.exe", string.Format("delete {0}", ServiceNameConst));
            if (res == 0)
            {
                Console.WriteLine("[SUCCESS] Service removed from SCM.");
            }
            else
            {
                Console.WriteLine("ERROR: sc.exe delete returned code " + res);
            }
            return res;
        }

        private static int StartServiceCommand()
        {
            return RunProcess("sc.exe", string.Format("start {0}", ServiceNameConst));
        }

        private static int StopServiceCommand()
        {
            return RunProcess("sc.exe", string.Format("stop {0}", ServiceNameConst));
        }

        private static int StatusServiceCommand()
        {
            return RunProcess("sc.exe", string.Format("query {0}", ServiceNameConst));
        }

        private static int RunProcess(string filename, string arguments)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(filename, arguments);
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.RedirectStandardError = true;
                psi.CreateNoWindow = true;

                using (Process p = Process.Start(psi))
                {
                    string stdout = p.StandardOutput.ReadToEnd();
                    string stderr = p.StandardError.ReadToEnd();
                    p.WaitForExit();

                    if (!string.IsNullOrEmpty(stdout)) Console.Write(stdout);
                    if (!string.IsNullOrEmpty(stderr)) Console.Write(stderr);

                    return p.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(string.Format("Failed to execute {0} {1}: {2}", filename, arguments, ex.Message));
                return -1;
            }
        }
    }
}
