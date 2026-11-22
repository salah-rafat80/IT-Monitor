import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bespoke, precision-crafted vector icons for IT Network Monitor (Enterprise NOC).
///
/// Designed with razor-sharp 1.8px geometric strokes, rounded joins, and
/// zero reliance on generic, cartoonish Material Design icon fonts.
class EnterpriseSvgIcons {
  EnterpriseSvgIcons._();

  // 1. Dashboard: Telemetry telemetry grid & system gauges
  static const String dashboard = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="7" height="9" rx="1.5"/>
  <rect x="14" y="3" width="7" height="5" rx="1.5"/>
  <rect x="14" y="12" width="7" height="9" rx="1.5"/>
  <rect x="3" y="16" width="7" height="5" rx="1.5"/>
</svg>
''';

  // 2. Devices: Workstation & server chassis setup
  static const String devices = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="3" width="14" height="11" rx="2"/>
  <path d="M6 18h6"/>
  <path d="M9 14v4"/>
  <rect x="18" y="7" width="4" height="11" rx="1.5"/>
  <circle cx="20" cy="15" r="0.75" fill="currentColor"/>
</svg>
''';

  // 3. Inventory: Hardware asset cube / inventory catalog
  static const String inventory = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>
  <path d="m3.3 7 8.7 5 8.7-5"/>
  <path d="M12 22V12"/>
</svg>
''';

  // 4. Infrastructure: Managed rack switches & fiber distribution
  static const String infrastructure = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="5" width="20" height="6" rx="1.5"/>
  <rect x="2" y="13" width="20" height="6" rx="1.5"/>
  <circle cx="6" cy="8" r="1" fill="currentColor"/>
  <circle cx="10" cy="8" r="1" fill="currentColor"/>
  <circle cx="6" cy="16" r="1" fill="currentColor"/>
  <circle cx="10" cy="16" r="1" fill="currentColor"/>
  <path d="M15 8h4M15 16h4"/>
</svg>
''';

  // 5. Topology: Connected network graph & hierarchical mesh
  static const String topology = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="5" r="3"/>
  <circle cx="5" cy="19" r="3"/>
  <circle cx="19" cy="19" r="3"/>
  <path d="M12 8v5M5 16l4.5-3.5M19 16l-4.5-3.5"/>
</svg>
''';

  // 6. Network Blueprint: Architectural CAD floorplan & cable routes
  static const String blueprint = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="18" height="18" rx="2"/>
  <path d="M3 9h18M9 21V9M9 15h12M15 9v12"/>
</svg>
''';

  // 7. Discovery: Radar sonar probe & active network sweep
  static const String discovery = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="9"/>
  <circle cx="12" cy="12" r="5"/>
  <circle cx="12" cy="12" r="1" fill="currentColor"/>
  <path d="m12 12 6.5-4.5"/>
</svg>
''';

  // 8. Settings: Precision technical gears & system configuration
  static const String settings = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="3"/>
  <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
</svg>
''';
}

/// Widget that renders a precision SVG icon with customizable color and size.
class EnterpriseSvgIcon extends StatelessWidget {
  final String svgString;
  final Color color;
  final double size;

  const EnterpriseSvgIcon({
    super.key,
    required this.svgString,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
