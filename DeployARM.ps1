#Requires -Modules @{ ModuleName="AzureStack"; ModuleVersion="2.1.0"}

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputTemplatePath = '.\Output',

     [Parameter(Mandatory = $true)]
     [ValidateSet('AzureAD','ADFS')]
     [string]$IdentityProvider,
 
     [Parameter(Mandatory = $true)]
     [string]$ArmEndpoint,

     [Parameter(Mandatory = $false)]
     [string]$AADTenantName,

     [Parameter(Mandatory = $false)]
     [string]$RegionName,
    
     [Parameter(Mandatory = $true)]
     [string]$AdminUsername,

     [Parameter(Mandatory = $true)]
     [securestring]$AdminPassword
 )
 
#Establish connection to Azure Stack Hub
 if ($IdentityProvider -eq 'AzureAD') {
     if ($AADTenantName -notin $null,'') {
        Add-AzEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint
        $AuthEndpoint = (Get-AzEnvironment -Name "AzureStackUser").ActiveDirectoryAuthority.TrimEnd('/')
        $TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]
    
        Connect-AzAccount -EnvironmentName "AzureStackUser" -TenantId $TenantId
     } else {
         throw "No $AADTenantName provided with Identity Provider type set to AzureAD. Example value is 'myAADTenantName.onmicrosoft.com'."
     }
    
 } elseif ($IdentityProvider -eq 'ADFS') {
    Add-AzEnvironment -Name "AzureStackUser" -ArmEndpoint $ArmEndpoint

    Connect-AzAccount -EnvironmentName "AzureStackUser"
 }

#Get List of templates within directory and determine Resource Group Names
$templateList = Get-ChildIem $OutputTemplatePath | Where-Object Name -like "*-armdeploy.json"
foreach ($templateFile in $templateList) {
    $resourceGroupName = $TemplateFile.Name.Substring(0,$TemplateFile.Name.Length-15)
    
    # Create resource group for template deployment
    Get-AzResourceGroup -Name $resourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent)
    {
        Write-Verbose "Creating Resource Group with name '$resourceGroupName'"
        New-AzResourceGroup -Name $RGName -Location $RegionName
    }
    else
    {
        Write-Verbose "Resource Group with name '$resourceGroupName' already exists."
    }

    $dateString = Get-Date -Format 'yyyyMMddHHmmss'
    $deploymentName = "deploy$resourceGroupName$dateString"

    Write-Verbose "Initiating Deployment with name '$deploymentName'."
    New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateUri $templateFile.FullName `
        -adminUsername $AdminUsername `
        -adminPassword $AdminPassword

}
