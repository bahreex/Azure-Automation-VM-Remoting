<#
.SYNOPSIS 
    Returns Status of the Azure RM VM

.DESCRIPTION
    This utility runbook determines the current status of the Azure RM VM and returns the value back to the caller
    
.PARAMETER ResourceGroupName
    Name of the resource group where the VM is located.

.PARAMETER VMName    
    Name of the VM that you want to connect to  

.EXAMPLE
    CheckAzureRMVMPowerState -ResourceGroupName "RG1" -VMName "VM01"
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 13/Dec/2017
    Last Revision Date: 13/Dec/2017
    Version: 1.0
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(
	[Parameter(Mandatory=$true)] 
	[String]$ResourceGroupName,
	
	[Parameter(Mandatory=$true)] 
    [String]$VMName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('PowerState','ProvisioningState')]
    [String]$State
)

if (!(Get-AzureRmContext).Account){
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount' with a valid Azure Organization Id (and not @outlook.com or any other Microsoft Live Id) having required permissions to the Azure Automation Account and Resource Group"
    return
}
                          
# Get current status of the VM in context fpr the Input State
$vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

# Check the current staus of VM in context for the Input State
foreach ($vstatus in $vmstatus.Statuses)
{
    if ($vstatus.Code.Contains($State))
    {
        return $vstatus.Code.split('/')[1]        
    }
} 

return                                                  
