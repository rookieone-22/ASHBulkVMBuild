# Bulk deploy VMs from a CSV to a single resource group
This script will deploy a list of VMs from a CSV with the following values set accross the list of VMs:
- virtualNetworkName
- subnetName
- resourceGroupName
- adminUsername
- adminPassword

This will use the Marketplace image for Windows using the version specified in the CSV.
The VM will only have a single NIC, named 'vmName'-nic01.
There dataDisks value in the CSV contains a list of disk sizes in GB seperated by a '|' character, e.g. 100|256|1000


TODO: Move name values in Template into Variables block, and then reference in resources. Will still need to do some replacement within resources but could potentially reduce complexity and provide method for generalising between OS types (linux vs Win)