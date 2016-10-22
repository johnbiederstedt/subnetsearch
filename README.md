
This plugin when called will prompt the user for a subnet, which must be provided in the form of a CIDR block; i.e. 172.16.24.1/25 for example.  Then will will assemble a vim style regular expression that will match all the IP addresses in that CIDR specified subnet including the network number and the broadcast address.  It then executes that search such that all the matching IP address are left highlighted.

It uses python 2, and as such needs the backported ipaddress module.  On any system that supports pip:

$ pip install backport_ipaddress

