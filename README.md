
This plugin when called will prompt the user for a subnet, which must be
provided in the form of a CIDR block; i.e. 172.16.24.1/25 for example.  Then
will will assemble a vim style regular expression that will match all the IP
addresses in that CIDR specified subnet including the network number and the
broadcast address.  It then executes that search such that all the matching IP
address are left highlighted.

![demo](https://cloud.githubusercontent.com/assets/940589/19622892/dd0ab1fc-987a-11e6-8436-c0af02d94fcc.gif)

Has been updated to compensate for arbitrary unicode errors in the mainline ipaddress module

