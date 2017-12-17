<#
.SYNOPSIS 
    Sets up the connection to an Azure ARM VM using Connect-AzureVM and remotes into it.

.DESCRIPTION
    This runbook gets called from within *Execute-AzureVMRemoting.ps1*, and sets up a connection to an Azure ARM virtual machine for remote execution of the script. It requires the Azure
    VM to have the Windows Remote Management service enabled and needs the Public IP of the VM to remote into it, which it does by calling the runbok *Connect-AzureVM.ps1*. It also checks to
    see if the script that needs to be executed on target VM is from an Inline string passed to it as a parameter, and accordingly executes the same on the target VM.

.PARAMETER RemoteVMCredName
    Azure Automation Credential Asset Name for the Credentials with which you wish to remote into the VM
    
.PARAMETER ResourceGroupName
    Name of the resource group where the VM is located.

.PARAMETER VMName    
    Name of the virtual machine that you want to connect to

.PARAMETER RemoteScript
    The string represetation of the Remote PS Script you want to execute on the target VMs

.EXAMPLE
    Remote-AzureVM -ResourceGroupName "RG1" -VMName "VM01" -RemoteVMCredName "VMCred" -RemoteScript "Write-Output 'Hello World!'"
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 6/Dec/2017
    Last Revision Date: 15/Dec/2017
    Version: 3.0
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(

	[Parameter(Mandatory=$true)] 
	[String]$RemoteVMCredName,
	
	[Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [String]$RemoteScript,

	[Parameter(Mandatory=$true)] 
    [String]$VMName
)   

    [ScriptBlock]$sb = [ScriptBlock]::Create($RemoteScript)

    try
    {   
        $IpAddress = .\Connect-AzureVM.ps1 `
            -VMName $VMName  `
            -ResourceGroupName $ResourceGroupName
               
        if($IpAddress -And $IpAddress -match "^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)`$")
        {
            Write-Output "The IP Address is $IpAddress. Attempting to remote into the VM.."

            $VMCredential = Get-AutomationPSCredential -Name $RemoteVMCredName

            $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck            

            Invoke-Command -ComputerName $IpAddress -Credential $VMCredential -UseSSL -SessionOption $sessionOptions -ScriptBlock $sb
        }
        else
        {
            Write-Output "Issue in obtaining IP Address for the VM {$VMName} in Resource Group {$ResourceGroupName}: $IpAddress"
        }
    }
    catch
    {
        Write-Output "Could not remote into the VM"
        Write-Output "Ensure that the VM is running and that the correct VM credentials are used to remote"
        Write-Output "Error in getting the VM Details.: $($_.Exception.Message) "
    }