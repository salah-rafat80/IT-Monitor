enum DeviceCategory {
  pc,
  laptop,
  mobile,
  ipCamera,
  printer,
  server,
  switchDevice,
  router,
  wirelessAccessPoint,
  otherNetworkDevice,
  other,
  unknown;

  static DeviceCategory fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'pc':
        return DeviceCategory.pc;
      case 'laptop':
        return DeviceCategory.laptop;
      case 'mobile':
      case 'phone':
      case 'smartphone':
      case 'tablet':
        return DeviceCategory.mobile;
      case 'ip_camera':
      case 'camera':
      case 'cctv':
      case 'nvr':
        return DeviceCategory.ipCamera;
      case 'printer':
        return DeviceCategory.printer;
      case 'server':
        return DeviceCategory.server;
      case 'switch':
      case 'switch_device':
        return DeviceCategory.switchDevice;
      case 'router':
      case 'gateway':
        return DeviceCategory.router;
      case 'access_point':
      case 'ap':
      case 'wireless_access_point':
      case 'wap':
        return DeviceCategory.wirelessAccessPoint;
      case 'other_network_device':
      case 'network_device':
        return DeviceCategory.otherNetworkDevice;
      case 'other':
        return DeviceCategory.other;
      default:
        return DeviceCategory.unknown;
    }
  }

  String toValue() {
    switch (this) {
      case DeviceCategory.pc:
        return 'pc';
      case DeviceCategory.laptop:
        return 'laptop';
      case DeviceCategory.mobile:
        return 'mobile';
      case DeviceCategory.ipCamera:
        return 'ip_camera';
      case DeviceCategory.printer:
        return 'printer';
      case DeviceCategory.server:
        return 'server';
      case DeviceCategory.switchDevice:
        return 'switch';
      case DeviceCategory.router:
        return 'router';
      case DeviceCategory.wirelessAccessPoint:
        return 'access_point';
      case DeviceCategory.otherNetworkDevice:
        return 'other_network_device';
      case DeviceCategory.other:
        return 'other';
      case DeviceCategory.unknown:
        return 'unknown';
    }
  }

  String get displayName {
    switch (this) {
      case DeviceCategory.pc:
        return 'PC / Workstation';
      case DeviceCategory.laptop:
        return 'Laptop';
      case DeviceCategory.mobile:
        return 'Mobile Device';
      case DeviceCategory.ipCamera:
        return 'IP Camera';
      case DeviceCategory.printer:
        return 'Printer';
      case DeviceCategory.server:
        return 'Server';
      case DeviceCategory.switchDevice:
        return 'Network Switch';
      case DeviceCategory.router:
        return 'Router / Gateway';
      case DeviceCategory.wirelessAccessPoint:
        return 'Wireless Access Point';
      case DeviceCategory.otherNetworkDevice:
        return 'Network Equipment';
      case DeviceCategory.other:
        return 'Other Asset';
      case DeviceCategory.unknown:
        return 'Unknown';
    }
  }
}
