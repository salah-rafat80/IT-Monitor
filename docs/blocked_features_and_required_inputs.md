# Blocked Features & Required Real Infrastructure Inputs

The following features cannot be activated or claimed operational until real physical infrastructure data and credentials are provided by network administrators:

## 1. Switch SNMP & Port-Level Active Monitoring
- **Current Status**: Switches exist strictly as static topology metadata grouping PC/Laptop endpoints. No active ICMP or SNMP status checks are run against switches.
- **Required Real Inputs**:
  - Switch Management IP addresses
  - Switch Vendor and exact model numbers
  - SNMP Version (v2c / v3)
  - SNMP Read Community String or SNMPv3 User Credentials (Username, Auth Key, Priv Key)
  - Physical switch port mapping to host MAC/IP addresses

## 2. Gateway, DNS, and External Network Monitoring
- **Current Status**: Only approved PC/Laptop endpoints are monitored.
- **Required Real Inputs**:
  - Primary & Secondary Gateway IP addresses
  - Internal DNS server IP addresses
  - Approved external internet test endpoint (e.g. 8.8.8.8, 1.1.1.1, or corporate portal)

## 3. UPS & Power Infrastructure Monitoring
- **Current Status**: No UPS objects are present in the inventory or monitored.
- **Required Real Inputs**:
  - UPS Management IP addresses & Vendor (e.g. APC, CyberPower, Eaton)
  - SNMP MIB specifications & credentials for UPS battery status, line voltage, and load percentage

## 4. Per-PC Internet Access Verification
- **Current Status**: Central Monitoring Host verifies ICMP reachability to PCs over LAN. Reachability to PC does not guarantee PC has active internet access.
- **Required Real Inputs**:
  - Endpoint client agent deployed on target PCs, OR outbound proxy/firewall log integration proving active internet session per PC.

## 5. Cross-VLAN Layer 2 Discovery (ARP across routed subnets)
- **Current Status**: Monitoring host at `192.168.27.64` performs direct Layer 2 ARP inspection for `192.168.27.0/24`. For routed subnet `192.168.22.0/24`, Layer 3 discovery (ICMP, reverse DNS, TCP allowlist) succeeds, but Layer 2 ARP broadcasts do not cross the router.
- **Required Real Inputs**:
  - Read access to Core Switch / Router ARP table (via SNMP or SSH) or multi-homed monitoring host interface on VLAN 22.

## 6. Video Stream Access & Camera Configuration
- **Current Status**: Discovered IP Cameras are fingerprinted via ONVIF WS-Discovery and RTSP port 554 and approved as assets only. Video streams are NOT accessed and credentials are NOT guessed.
- **Required Real Inputs**:
  - Camera credentials and authorized video stream profile URLs for any future camera monitoring phase.
