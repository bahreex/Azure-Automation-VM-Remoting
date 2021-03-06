<#
.SYNOPSIS 
    Sets up connection to all Azure ARM VMs in an Azure Subscription, by enabling Win RM on all of them through Connect-AzureVM, and remote into
    them through Remote-AzureVM to execute commands/script.

.DESCRIPTION
    This runbook is the entry point for setting up and remotely executing Powershell scripts on one/more/all Azure ARM virtual machines in your Azure Subscription. 
    It enables you to traverse through all resource groups and corresponding VMs in your Azure Subscription, check the current state of VMs (and skip the deallocated ones), 
    check OS type (Windows or Linux, and skip Linux ones). Thereafter, this script triggers child runbooks to enable and configure Windows Remote Management service on each VM,
    setup a connection to the Azure subscription, get the public IP Address of the VM, and remote into it to for execution of whatever commands/script needs to be executed there.
    You also need to pass the script to be executed on the VMs as an Inline string.

.PARAMETER KeyVaultName
    Name of the Azure KeyVault, where username/password for each of the VMs are stored. 
    Assuming Username and Passwords for each VM are stored in Azure Keyvault in the format - Name = <VM Name>, Secret = <Domain:Username:Password> (Domain can be empty) 

.PARAMETER AzureAutomationAccountName
    Name of the Azure Automation Account, from where this runbook will be run

.PARAMETER AzureAutomationResourceGroupName
    Name of the Resource Group for the Azure Automation Account, from where this runbook will be run

.PARAMETER RemoteScript
    The string represetation of the Remote PS Script you want to execute on the target VMs

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to remote Into. Specifying just the Resource Group without the $VMName parameter, will consider all VMs in this specified Resource Group

.PARAMETER VMName    
    Name of the VM you want to remote Into. this parameter cannot be specified without it's Resource group in the $ResourceGroupName parameter, or else will throw error  

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" -AzureAutomationResourceGroupName "Automation-RG1" -ResourceGroupName "RG1" -VMName "VM01"  -RemoteScript "Write-Output 'Hello World!'"
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 6/Dec/2017
    Last Revision Date: 17/Dec/2017
    Version: 4.0
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$KeyVaultName,

    [Parameter(Mandatory=$true)] 
    [String]$AzureAutomationAccountName,

    [Parameter(Mandatory=$true)] 
    [String]$AzureAutomationResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [String]$RemoteScript,
    
    [Parameter()]
    [String]$ResourceGroupName,
    
    [Parameter()]
    [String]$VMName	
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName'))
{
    # Get a list of all the Resource Groups in the Azure Subscription
    $RGs = Get-AzureRmResourceGroup -ErrorAction "SilentlyContinue"
    
    # Check if there are Resource Groups in the current Azure Subscription
    if ($RGs)
    {        
        # Iterate through all the Resource Groups in the Azure Subscription        
        foreach ($rg in $RGs)
        {
            $RGBaseName = $rg.ResourceGroupName
            
            # Get a list of all the VMs in the specific Resource Group for this Iteration
            $VMs = Get-AzureRmVm -ResourceGroupName $RGBaseName -ErrorAction "SilentlyContinue"

            if ($VMs)
            {
                # Iterate through all the VMs within the specific Resource Group for this Iteration
                foreach ($vm in $VMs)
                {
                    $VMBaseName = $vm.Name

                    $OSX = .\Get-AzureRMVMOSType.ps1 -ResourceGroupName $RGBaseName -VMName $VMBaseName
                    
                    if ($OSX -And $OSX -eq "Linux")
                    {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is on $OSX OS. Hence, cannot process further since only Windows OS supported. Skipping forward."
                        continue
                    }
                    
                    $VMState = .\Get-AzureRMVMState.ps1 -ResourceGroupName $RGBaseName -VMName $VMBaseName -State "PowerState"
                    
                    if ($VMState -And $VMState -eq "deallocated")
                    {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated. Hence, cannot get IP address, and skipping."
                        continue
                    }

                    # Form standardized name of the Azure Automation PS Credential for the VM in context
                    $RemoteVMCredName = $VMBaseName + "-AACredential"
                    
                    # For the VM in context, extract the corresponding username/password from Azure KeyVault
                    $secret = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $VMBaseName

                    # Call the script to check if the Azure Automation Credential for the VM in context alredy exists, and create a new one if absent
                    $SetCredentials = .\Create-AzureAutomationCredentials.ps1 -AzureAutomationAccountName $AzureAutomationAccountName `
                    -AzureAutomationResourceGroupName $AzureAutomationResourceGroupName `
                    -CredentialName $VMBaseName `
                    -UserName $vm.oSProfile.AdminUsername `
                    -Password $secret.SecretValueText

                    if ($SetCredentials -eq 0)
                    {                    
                        # Call PS Script to Remote Into the VM in context
                        .\Remote-AzureARMVMPS.ps1 -RemoteVMCredName $RemoteVMCredName `
                        -ResourceGroupName $RGBaseName `
                        -VMName $VMBaseName `
                        -RemoteScript $RemoteScript
                    }
                    else
                    {
                        Write-Output "Unable to get or set Azure Automation Credentials for VM {$VMBaseName}. Skipping forward..."
                        continue
                    }
                }
            }
            else
            {
                Write-Output "There are no VMs in the Resource Group {$RGBaseName}. Continuing with next Resource Group, if any."
                continue
            }
        }
    }
    else
    {
        Write-Output "There are no Resource Groups in the Azure Subscription. Aborting..."
        return
    }
}
# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName'))
{
    # Get a list of all the VMs in the specific Resource Group
    $VMs = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -ErrorAction "SilentlyContinue"
    
    if ($VMs)
    {
    # Iterate through all the VMs within the specific Resource Group for this Iteration
        foreach ($vm in $VMs)
        {
            $VMBaseName = $vm.Name

            $OSX = .\Get-AzureRMVMOSType.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMBaseName
            
            if ($OSX -And $OSX -eq "Linux")
            {
                Write-Output "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is on $OSX OS. Hence, cannot process further since only Windows OS supported. Skipping forward."
                continue
            }

            $VMState = .\Get-AzureRMVMState.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMBaseName -State "PowerState"
            
            if ($VMState -And $VMState -eq "deallocated")
            {
                Write-Output "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is currently Deallocated. Hence, cannot get IP address, and skipping."
                continue
            }

            # Form standardized name of the Azure Automation PS Credential for the VM in context
            $RemoteVMCredName = $VMBaseName + "-AACredential"
            
            # For the VM in context, extract the corresponding username/password from Azure KeyVault
            $secret = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $VMBaseName

            # Call the script to check if the Azure Automation Credential for the VM in context alredy exists, and create a new one if absent
            $SetCredentials = .\Create-AzureAutomationCredentials.ps1 -AzureAutomationAccountName $AzureAutomationAccountName `
            -AzureAutomationResourceGroupName $AzureAutomationResourceGroupName `
            -CredentialName $VMBaseName `
            -UserName $vm.oSProfile.AdminUsername `
            -Password $secret.SecretValueText

            if ($SetCredentials -eq 0)
            {
                # Call PS Script to Remote Into the VM in context
                .\Remote-AzureARMVMPS.ps1 -RemoteVMCredName $RemoteVMCredName `
                -ResourceGroupName $ResourceGroupName `
                -VMName $VMBaseName `
                -RemoteScript $RemoteScript
            }
            else
            {
                Write-Output "Unable to get or set Azure Automation Credentials for VM {$VMBaseName}. Skipping forward..."
                continue
            }
        }
    }
    else
    {
        Write-Output "There are no Virtual Machines in Resource Group {$ResourceGroupName}. Aborting..."
        return
    }
}
# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName'))
{

    # Get the specified VM in the specific Resource Group
    $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction "SilentlyContinue"

    if ($vm)
    {    
        $VMBaseName = $vm.Name

        $OSX = .\Get-AzureRMVMOSType.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMBaseName
        
        if ($OSX -And $OSX -eq "Linux")
        {
            Write-Output "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is on $OSX OS. Hence, cannot process further since only Windows OS supported. Skipping forward."
            continue
        }

        $VMState = .\Get-AzureRMVMState.ps1 -ResourceGroupName $ResourceGroupName -VMName $VMBaseName -State "PowerState"
        
        if ($VMState -And $VMState -eq "deallocated")
        {
            Write-Output "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is currently Deallocated. Hence, cannot get IP address, and skipping."
            continue
        }

        # Form standardized name of the Azure Automation PS Credential for the VM in context
        $RemoteVMCredName = $VMBaseName + "-AACredential"
        
        # For the VM in context, extract the corresponding username/password from Azure KeyVault
        $secret = Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $VMBaseName
        
        # Call the script to check if the Azure Automation Credential for the VM in context alredy exists, and create a new one if absent
        $SetCredentials = .\Create-AzureAutomationCredentials.ps1 -AzureAutomationAccountName $AzureAutomationAccountName `
        -AzureAutomationResourceGroupName $AzureAutomationResourceGroupName `
        -CredentialName $VMBaseName `
        -UserName $vm.oSProfile.AdminUsername `
        -Password $secret.SecretValueText
        
        if ($SetCredentials -eq 0)
        {
            # Call PS Script to Remote Into the VM in context
            .\Remote-AzureARMVMPS.ps1 -RemoteVMCredName $RemoteVMCredName `
            -ResourceGroupName $ResourceGroupName `
            -VMName $VMBaseName `
            -RemoteScript $RemoteScript
        }
        else
        {
            Write-Output "Unable to get or set Azure Automation Credentials for VM {$VMBaseName}. Skipping forward..."
            return
        }
    }
    else
    {
        Write-Output "There is no Virtual Machine named {$VMName} in Resource Group {$ResourceGroupName}. Aborting..."
        return
    }
}
# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName'))
{
    Write-Error "VM Name parameter cannot be specified alone, without specifying its Resource Group Name parameter also. Aborting..."
    return
}    