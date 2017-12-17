# Azure-Automation-VM-Remoting
_*Azure Automation Runbooks: Enabling/providing capability to remotely execute PowerShell commands/scripts on remote Windows based VM's in Azure*_

Here is a set of PowerShell based Azure Automation Runbooks, which can be used to remote into one or more or *all* Windows Server VMs within an Azure Subscription, and remotely execute any PowerShell commands/scripts on those VMs.

By default, Azure RM VMs with any Azure marketplace based Windows Server OS do not have WinRM enabled/configured from within OS (Since advent of ARM model). Also any Azure NSG's applicable to these VMs do not allow any WinRM communication (over port 5986) by default. These Runbooks configure the VMs to enable WinRM on them, open access over WinRM, configure NSGs to allow WinRM over HTTPS, and enable the user to execute PowerShell commands/scripts remotely on these Azure VMs.

## Key pre-requisites:

- The Azure VMs being targeted need to have Public IPs and Internet connection for them to be able to download the configuration scripts from a public Uri

- You need to have an Azure KeyVault (AKV) configured in your Azure subscription. This AKV will need to contain Passwords (as Secrets) corresponding to all your VMs you want to remote into. For the Name part, enter the VM name, for the value part, enter Password. You also need to give the Automation SPN used to authorize this script, access permissions on the AKV, without which the SPN won't be able to access any AKV secrets. Hence, you need to choose the "Secret Management" template in AKV under the "Access Permissions" section, and choose default 7 permissions already selected under "Secret Permissions" dropdown, and assign to the Automation SPN.

- You need to give the Automation SPN you are using to run this script, Contributor access to all the Resource Groups in your subscription, otherwise script will not be able to pull Information for the VMs in those resource groups

- You will need an Azure Automation (AA) Account already setup in your subscription, under whichever resource group you may want to. Within this AA account, AA Credentials for all VM users will be automatically managed by this script itself so you need not worry about them. Once the AA Credentials of a VM are created by the script, next time onwards those same credentials will be reused, without creating any duplicates. The nomenclature used for the Credential name is "<VM Name>--AACredential"

- This version of the script works for both Azure VMs with Managed and Unmanaged disks. It does not rely on Azure Storage for storing the temporary script to configure the   VMs for PS Remoting by enabling WinRM through custom script extension within the VM. Instead, script for WinRm configuration in VMs comes from a publicly available Github GIST file linked to my Github account hosting this repository itself. You are free to link to any publicly available Uri hosting the temporary script, if you do not want this script to link to my GIST file, for which you will need to as-is copy raw format of my GIST file from its location.

Below listed are the constituent Azure Automation runbooks, and their brief descriptions:

### Launch.ps1

This Runbook is for demonstrating how to call *Execute-AzureVMRemoting.ps1* with required parameters. If running from VS Code, you will need to either be already logged into
your Azure account, or use "Login-AzureRmAccount" command within this file to first log into Azure before executing the runbook.

### Execute-AzureVMRemoting.ps1

This runbook is the entry point for setting up and remotely executing Powershell scripts on one/more/all Azure ARM virtual machines in your Azure Subscription.
It enables you to traverse through all resource groups and corresponding VMs in your Azure Subscription, check the current state of VMs (and skip the deallocated ones),
check OS type (Windows or Linux, and skip Linux ones). Thereafter, this script triggers child runbooks to enable and configure Windows Remote Management service on each VM,
setup a connection to the Azure subscription, get the public IP Address of the VM, and remote into it to for execution of whatever commands/script needs to be executed there.
You also need to pass the script to be executed on the VMs either as an Inline string.

### Create-AzureAutomationCredentials.ps1

This runbook checks for presence of an Azure Automation credential within a particular Azure Subscription and an Azure Automation Account corresponding to the Information
passed through parameters, and creates a new one if it does not exist. It enables you to pass your own text suffix as a parameter to be used to form a unique name for the
credential, or takes a default hardcoded suffix otherwise. It gets called from within *Execute-AzureVMRemoting.ps1*

### Get-AzureRMVMOSType.ps1

This utility runbook determines the OS type of the Azure RM VM (Windows/Linux etc.) and returns the value back to the caller. It gets called from within *Execute-AzureVMRemoting.ps1*

### Get-AzureRMVMState.ps1

This utility runbook determines the current status of the Azure RM VM and returns the value back to the caller. It gets called from within *Execute-AzureVMRemoting.ps1*

### Remote-AzureVM.ps1

This runbook gets called from within *Execute-AzureVMRemoting.ps1*, and sets up a connection to an Azure ARM virtual machine for remote execution of the script. It requires the Azure
VM to have the Windows Remote Management service enabled and needs the Public IP of the VM to remote into it, which it does by calling the runbok *Connect-AzureVM.ps1*. It also checks to
see if the script that needs to be executed on target VM is from an Inline string passed to it as a parameter, and accordingly executes the same on the target VM.

### Connect-AzureVM.ps1

This runbook gets called from within "Remote-AzureVM.ps1" sets up a connection to an Azure ARM virtual machine. It requires the Azure virtual machine to have the Windows Remote Management service enabled.
It enables WinRM and configures it on your VM, after which it sets up a connection to the Azure subscription, gets the public IP Address of the virtual machine and return it to *Remote-AzureVM.ps1*. This
runbook works for VMs with both Managed and Unmanaged disks
