<#
.SYNOPSIS 
    Returns OS type of the Azure RM VM

.DESCRIPTION
    This utility runbook determines the OS type of the Azure RM VM (Windows/Linux etc.) and returns the value back to the caller
    
.PARAMETER ResourceGroupName
    Name of the resource group where the VM is located.

.PARAMETER VMName    
    Name of the VM that you want to connect to  

.EXAMPLE
    CheckAzureRMVMOSType -ResourceGroupName "RG1" -VMName "VM01"
    
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
	[String]$VMName	
)

if (!(Get-AzureRmContext).Account){
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount' with a valid Azure Organization Id (and not @outlook.com or any other Microsoft Live Id) having required permissions to the Azure Automation Account and Resource Group"
    return
}

$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

If ($vm)
{
    # Return OS Type of the VM
    return $vm.StorageProfile.OsDisk.OsType.ToString()                            
}