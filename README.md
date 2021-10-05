# Azure Stack Hub - Generate VM ARM Templates from CSV and deploy them #

The following scripts are designed to allow the bulk creation of Virtual Machines to an Azure Stack Hub platform.

There are two scripts that should be executed in order: 
1. CreateARM.ps1 - This script creates an ARM template for a single resource group using a CSV input file
2. DeployARM.ps1 - This script will deploy the previously created ARM template file(s) to the Azure Stack Hub
_Note: an additional script called 'HelperFunctions.ps1' must also exist in the same directory as the above scripts in order for proper execution. This script contains additional functions which assist in simplifying the two main scripts._


## CreateARM.ps1 ##
In order to simplify the template creation process, the following values will be the same accross all VMs within the single resource group:
- virtualNetworkName
- virtualNetworkResourceGroupName
- subnetName

The script is designed to work with Marketplace images for VMs using the fields provided in the CSV input template, but could be modified to work with custom images if required.
The VMs will only have a single NIC, named "'vmName'-nic01".
The dataDisks value in the CSV contains a list of disk sizes in GB seperated by a '|' character, e.g. 100|256|1000. The disks will be named "'vmName'-datadisk'lun#''"

This script also contains a check for each VMSize value to ensure its one of the supported sizes for the Azure Stack Hub platform.

### Example Execution ###
`.\CreateARM.ps1 -ResourceGroupCSV .\resourcegrouptemplate.csv -ResourceGroupName 'testrg01' -VirtualNetworkName 'testvnet01' -VirtualNetworkResourceGroup 'testrgvnet01' -SubnetName 'subnet01' -Verbose`

### Execution Paramters ###
- ResourceGroupCSV - Required: FALSE - Default Value: '.\resourcegrouptemplate.csv'
- ResourceGroupName - Required: TRUE
- VirtualNetworkName - Required: TRUE
- VirtualNetworkResourceGroup - Required: TRUE 
- SubnetName - Required: TRUE
- OutputTemplatePath - Required: FALSE - Default Value: '.\Output'

## DeployARM.ps1 ##

***UNTESTED - components of this script havent been tested against Azure Stack Hub so please use with care***

This script requires the AzureStack Powershell modules (with dependent Az modules) to be installed on the executing machine. See here (https://docs.microsoft.com/en-us/azure-stack/operator/powershell-install-az-module) for how to install.

The script will take all ARM Resource Group templates within the provided folder, and then execute a deployment for each using the parameter values provided.

### Example Execution ###
`.\DeployARM.ps1 -IdentityProvider 'ADFS' -ArmEndpoint 'https://management.region.azurestack.fqdn' -RegionName 'region' -AdminUsername 'testadmin' -AdminPassword ('<PASSWORD>' | ConvertTo-SecureString -AsPlainText -Force) -Verbose`

or

`.\DeployARM.ps1 -IdentityProvider 'AzureAD' -ArmEndpoint 'https://management.region.azurestack.fqdn' -AADTenantName 'myAADTenant.onmicrosoft.com' -RegionName 'region' -AdminUsername 'testadmin' -AdminPassword ('<PASSWORD>' | ConvertTo-SecureString -AsPlainText -Force) -Verbose`

### Execution Paramters ###
- OutputTemplatePath - Required: FALSE - Default Value: '.\Output'
- IdentityProvider - Required: TRUE - Set Values: 'AzureAD' or 'ADFS
- ArmEndpoint - Required: TRUE
- AADTenantName - Required: FALSE - ***Required for AzureAD Identity Provider***
- RegionName - Required: TRUE
- AdminUsername - Required: TRUE
- AdminPassword - Required: TRUE - Type: SecureString

