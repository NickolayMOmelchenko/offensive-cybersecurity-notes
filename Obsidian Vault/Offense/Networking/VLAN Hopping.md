**Switch Spoofing**
- Requires Dynamic Trunking Protocol (DTP) to be enabled on the switch.
- Attackers device can pretend to be a switch then send trunk negotiation.
- Therefore - ﻿send and receive from any configured VLAN.
**Double Tagging**
- Requires "native" VLAN configuration
- Craft a packet that includes two VLAN tags
- Cons: There is no way to receive a response back from the victim. ![[Screenshot 2024-12-28 at 8.52.26 AM.png]]