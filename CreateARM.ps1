param(
     [Parameter()]
     [string]$ResourceGroupCSV = '.\resourcegrouptemplate.csv',

     [Parameter(Mandatory = $true)]
     [string]$ResourceGroupName,
 
     [Parameter(Mandatory = $true)]
     [string]$VirtualNetworkName,

     [Parameter(Mandatory = $true)]
     [string]$VirtualNetworkResourceGroup,

     [Parameter(Mandatory = $true)]
     [string]$SubnetName,

     [Parameter()]
     [string]$OutputTemplatePath = '.\Output'
 )
 
#Load HelperFunctions
$HelperFunctions = "$($MyInvocation.MyCommand.path | Split-Path)\HelperFunctions.ps1"
. $HelperFunctions

$TemplatePath = 'ARMTemplate\azuredeploy.json'

#Load in template
$JSONContent = Get-Content -Raw (Join-Path $PSScriptRoot -ChildPath $TemplatePath)
$ARMVMTemplate = ConvertFrom-Json -InputObject $JSONContent

<# Current Template Resource Types are as follows:
    0 - Microsoft.Storage/storageAccounts
    1 - Microsoft.Network/networkInterfaces
    2 - Microsoft.Compute/disks
    3 - Microsoft.Compute/virtualMachines
#>
$StorageAccountObjectTemplate = $ARMVMTemplate.resources[0]
$NICObjectTemplate = $ARMVMTemplate.resources[1]
$DISKObjectTemplate = $ARMVMTemplate.resources[2]
$VMObjectTempate = $ARMVMTemplate.resources[3]
$VMDataDiskTemplate = $ARMVMTemplate.resources[3].properties[0].storageProfile.dataDisks[0]
$VMImageRefenceTemplate = $ARMVMTemplate.resources[3].properties[0].storageProfile.imageReference

#Copy template object and clear out resources and readd diagnositcs storage account
$ARMTemplateOutput = Copy-Object $ARMVMTemplate
$ARMTemplateOutput.resources = @()
$ARMTemplateOutput.resources += $StorageAccountObjectTemplate

#Update Variables with VNet and Subnet values
$ARMTemplateOutput.variables.virtualNetworkResourceGroup = $VirtualNetworkResourceGroup
$ARMTemplateOutput.variables.virtualNetworkName = $VirtualNetworkName
$ARMTemplateOutput.variables.subnetName = $SubnetName

#Load in CSV
$CSV = Import-Csv -Path $ResourceGroupCSV

foreach ($row in $CSV) {
    
    #Setup VM Params
    $vmName = $row.vmName
    $nicName = "$($vmName)-nic01"
    $vmSize = $row.vmSize
    Write-Verbose "Starting loop for VMName: $vmName"

    $storageObjectReference = "[resourceId('Microsoft.Storage/storageAccounts',variables('storageAccountName'))]"
    
    $vmDependsOn = @()
    $vmDependsOn += $storageObjectReference

    #Verify VM Size
    if ( -not (Test-ASHVMSize $vmSize)) {
        Write-Warning "Unknown value selected for VM Size: $vmSize - VMName: $vmName"
        Continue
    }
    
    #Create and populate NIC Object
    $newNICObject = Copy-Object $NICObjectTemplate
    $newNICObject.name = $nicName

    Write-Verbose "Creating NIC Object with following name: $nicName"
    $newNICObjectReference = "[resourceId('Microsoft.Network/networkInterfaces','$nicName')]"
    $vmDependsOn += $newNICObjectReference
    $ARMTemplateOutput.resources += $newNICObject

    #Create and populate DataDisks
    
    $ddCount = 1
    $vmDataDisksObject = @()

    if ($row.dataDisks -notin $null,'') {
        $dataDisksSizeArray = $row.dataDisks.Split('|')
        foreach ($dataDiskSize in $dataDisksSizeArray) {
            #Test value is a Int
            [Int32]$dataDiskSizeInt = $null
            if ([Int32]::TryParse($dataDiskSize,[ref]$dataDiskSizeInt)){
                $dataDiskName = "$($vmName)-datadisk$ddCount"

                $newDataDiskObject = Copy-Object $DISKObjectTemplate
                $newDataDiskObject.name = $dataDiskName
                $newDataDiskObject.properties.diskSizeGB = $dataDiskSizeInt

                Write-Verbose "Creating DataDisk Object with following values: $dataDiskName - $dataDiskSizeInt"
                $newDataDiskRef = "[resourceId('Microsoft.Compute/disks','$dataDiskName')]" 
                $vmDependsOn += $newDataDiskRef
                $ARMTemplateOutput.resources += $newDataDiskObject

                Write-Verbose "Creating VM DataDisk Object with following values: $ddCount - $dataDiskName - $newDataDiskRef"
                $vmDataDiskObject = Copy-Object $VMDataDiskTemplate
                $vmDataDiskObject.lun = $ddCount
                $vmDataDiskObject.name = $dataDiskName
                $vmDataDiskObject.managedDisk.id = $newDataDiskRef
                $vmDataDisksObject += $vmDataDiskObject

                $ddCount ++

            } else {
                Write-Warning "Invalid Number in Disk array: '$dataDiskSize' - no DataDisk added for this"
            }
        }
    } else {
        Write-Verbose "No Datadisk value found, creating 0 dataDisks"
    }
    
    #Create VM imageReference
    Write-Verbose "Creating VM Image Refence Object with following values: publisher $($row.imagePublisher) offer $($row.imageOffer) sku $($row.imageSku)"
    $vmImageReferenceObject = Copy-Object $VMImageRefenceTemplate
    $vmImageReferenceObject.publisher = $row.imagePublisher
    $vmImageReferenceObject.offer = $row.imageOffer
    $vmImageReferenceObject.sku = $row.imageSku

    #Create and populate VM Object
    $vmObject = Copy-Object $VMObjectTempate
    $vmObject.name = $vmName
    $vmObject.dependsOn = $vmDependsOn
    $vmObject.properties.hardwareProfile.vmSize = $vmSize
    $vmObject.properties.osProfile.computerName = $vmName
    $vmObject.properties.storageProfile.imageReference = $vmImageReferenceObject
    $vmObject.properties.storageProfile.dataDisks = $vmDataDisksObject
    $vmObject.properties.networkProfile.networkInterfaces[0].id = $newNICObjectReference

    Write-Verbose "Creating VM Object with following values: $vmName - $vmSize"
    Write-Verbose "VM DependsOn: $vmDependsOn"
    Write-Verbose "VM Number of DataDisks: $($ddCount - 1)"
    Write-Verbose "VM NIC Reference: $newNICObjectReference"
    $ARMTemplateOutput.resources += $vmObject

}

# Output completed template if there are some resources
$outputTemplateFilePath = Join-Path $OutputTemplatePath -ChildPath "$ResourceGroupName-armdeploy.json"
ConvertTo-Json -InputObject $ARMTemplateOutput -Depth 100 | Format-Json -Indentation 2 | Out-File $outputTemplateFilePath 



