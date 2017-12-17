<#
.SYNOPSIS 
    Checks for an Azure Automation Credential within a particular Azure Subscription and Azure Automation Account, and creates a new Azure Automation Credential if not present

.DESCRIPTION
    This runbook checks for presence of an Azure Automation credential within a particular Azure Subscription and an Azure Automation Account corresponding to the Information passed through parameters, 
    and creates a new one if it does not exist. It enables you to pass your own text suffix as a parameter to be used to form a unique name for the credential, or takes a default hardcoded suffix otherwise.

.PARAMETER AzureAutomationAccountName
    Name of the Azure Automation Account, from where this runbook will be run

.PARAMETER AzureAutomationResourceGroupName
    Name of the Resource Group for the Azure Automation Account, from where this runbook will be run

.PARAMETER CredentialName
    Name of the Azure Automation Credential you want to either check the existence of, or be created if absent

.PARAMETER Suffix    
    The suffix you want to be added to the CredentialName parameter to form a unique name in case a new credential has to be created. If you do not provide any suffix value and skip the parameter, a default value of "-AACredential" is assumed

.PARAMETER UserName
    Name of the User for which the new credential will be created.

.PARAMETER Password  
    Password value for the User, for which the new credential will be created.

.EXAMPLE
    Create-AzureAutomationCredentials.ps1 -AzureAutomationAccountName "Automation-AC1" -AzureAutomationResourceGroupName "Automation-RG1" -CredentialName "vm-2016-01" -UserName "xadmin" -Password "Pass@101"

.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 12/Dec/2017
    Last Revision Date: 15/Dec/2017
    Version: 3.0
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

 Param(
    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]$AzureAutomationAccountName,

    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]$AzureAutomationResourceGroupName,

    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]$CredentialName,

    # Parameter help description
    [Parameter()]
    [String]$Suffix = "-AACredential",

    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]$UserName,

    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]$Password
)

    $ErrorActionPreference = "SilentlyContinue"

    if (!(Get-AzureRmContext).Account){
        Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount' with a valid Azure Organization Id (and not @outlook.com or any other Microsoft Live Id) having required permissions to the Azure Automation Account and Resource Group"
        return
    }

    # Form standardized name of the Azure Automation PS Credential for the Input credential Info
    $CredName = $CredentialName + $Suffix    

    # Get all the existing Azure Automation PS Credential for the Input credential Info
    $CredsCollection = Get-AzureRmAutomationCredential -ResourceGroupName $AzureAutomationResourceGroupName -AutomationAccountName $AzureAutomationAccountName
    
    if ($CredsCollection)
    {
        # Iterate through all existing Automation PS Credential to check for presence of that for the Input credential Info
        foreach ($credItem in $CredsCollection)
        {                    
            if ($credItem.Name -eq $CredName)
            {
                $Cred = $credItem
                break
            }
        }
    }

    # If Azure Automation PS Credential for the Input credential Info is null
    if (!$Cred)
    {
        # Get Secure version of the Input Password
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force        
        
        # Form PS Credential Object from the Input User Name and Password
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
        
        # Creat new Azure Automation PS Credential object for the Input credential Info
        $vmAzureAutomationCredential = New-AzureRmAutomationCredential -AutomationAccountName $AzureAutomationAccountName -Name $CredName -Value $Credential -ResourceGroupName $AzureAutomationResourceGroupName

        if (!$vmAzureAutomationCredential)
        {
            Write-Error "Unable to create Azure Automation Credential for {$CredentialName}."
            return
        }
        else {
            return 
        }
    }
    else {
        return
    }