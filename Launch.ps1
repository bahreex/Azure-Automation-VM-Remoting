## Please uncomment/comment lines as you may wish. This is just for ddemonstrating how to use the Execute-AzureVMRemoting function 
## within the Execute-AzureVMRemoting.ps1 file. Please fill in appropriate values for the parameters required for different cases
## as configured at your end.

# Test: 1
Write-Output "Test #1: Without Resource Group Name and VM Name Params"
$RemoteScript = "Write-Output 'Hello World!!!!'"

.\Execute-AzureVMRemoting.ps1 -AzureSubscriptionId "" `
-AzureOrgIdCredentialName "" -KeyVaultName "" `
-AzureAutomationAccountName "" -AzureAutomationResourceGroupName "" -RemoteScript $RemoteScript

#Login-AzureRmAccount

<#
# Test: 2
Write-Output "Test #2: With Resource Group Name Without VM Name Params"
$RemoteScript = ""
.\Execute-AzureVMRemoting.ps1 -AzureSubscriptionId "" `
-AzureOrgIdCredentialName "" -KeyVaultName "" `
-AzureAutomationAccountName "" -AzureAutomationResourceGroupName "" -ResourceGroupName "" -RemoteScript ""

# Test: 3
Write-Output "Test #3: With Resource Group Name and VM Name Params"
$RemoteScript = ""
.\Execute-AzureVMRemoting.ps1 -AzureSubscriptionId "" `
-AzureOrgIdCredentialName "" -KeyVaultName "" `
-AzureAutomationAccountName "" -AzureAutomationResourceGroupName "" -ResourceGroupName "" -VMName "" -RemoteScript ""

# Test: 4
Write-Output "Test #4: Without Resource Group Name and With VM Name Params"
$RemoteScript = ""
.\Execute-AzureVMRemoting.ps1 -AzureSubscriptionId "" `
-AzureOrgIdCredentialName "" -KeyVaultName "" `
-AzureAutomationAccountName "" -AzureAutomationResourceGroupName "" -VMName "" -RemoteScript ""
#>
