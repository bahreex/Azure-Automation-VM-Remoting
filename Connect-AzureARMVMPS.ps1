<#
.SYNOPSIS 
    Sets up the connection to an Azure ARM VM through Win RM

.DESCRIPTION
    This runbook sets up a connection to an Azure ARM virtual machine. It requires the Azure virtual machine to
    have the Windows Remote Management service enabled. It enables WinRM and configures it on your VM, after which it sets up a connection to the Azure
	subscription, gets the public IP Address of the virtual machine and return it. This runbook works for VMs with both Managed and Unmanaged disks.

.PARAMETER ResourceGroupName
    Name of the resource group where the VM is located.

.PARAMETER VMName
    Name of the virtual machine that you want to connect to  

.EXAMPLE
    Connect-AzureVM -ResourceGroupName "RG1" -VMName "VM01"

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

Param
(            
    [parameter(Mandatory=$true)]
    [String]$ResourceGroupName,
    
    [parameter(Mandatory=$true)]
    [String]$VMName      
)

$ErrorActionPreference = "SilentlyContinue"

# Get the VM we need to configure
$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

#--------------------------------------------------------------------------------------------------------

$DNSName = $env:COMPUTERNAME
$SourceAddressPrefix = "*"

# Define a temporary configuration script file in the users TEMP directory
$file = $env:TEMP + "\ConfigureWinRM_HTTPS.ps1"
$string = "param(`$DNSName)" + "`r`n" + "Enable-PSRemoting -Force" + "`r`n" + "New-NetFirewallRule -Name 'WinRM HTTPS' -DisplayName 'WinRM HTTPS' -Enabled True -Profile 'Any' -Action 'Allow' -Direction 'Inbound' -LocalPort 5986 -Protocol 'TCP'" + "`r`n" + "`$thumbprint = (New-SelfSignedCertificate -DnsName `$DNSName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint" + "`r`n" + "`$cmd = `"winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"`"`$DNSName`"`"; CertificateThumbprint=`"`"`$thumbprint`"`"}`"" + "`r`n" + "cmd.exe /C `$cmd"
$string | Out-File -FilePath $file -force

if ($VM)    
{
    # Add Azure CustomScript Extension to the VM in context, and download/run a custom PS configuration script located on a remote Uri location (on a Public Github GIST within the repository for this Runbook)
    $extension = Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VM.Name -Name "EnableWinRM_HTTPS" `
    -Location $VM.Location -RunFile "ConfigureWinRM_HTTPS.ps1" -Argument $DNSName `
    -FileUri "https://gist.githubusercontent.com/bahreex/526de42953a13ef0e3f3af093cff6a74/raw/b6e42d627d37cd39dc0e31e851a3c1b9230ebc0e/ConfigureWinRM_HTTPS.ps1"

    # Get the name of the first NIC in the VM
    $nicName = Get-AzureRmResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id

    # Get NIC object for the first NIC in the VM
    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName.ResourceName

    # Get the network security group attached to the NIC
    $nsgRes = Get-AzureRmResource -ResourceId $nic.NetworkSecurityGroup.Id
    $nsg = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $ResourceGroupName  -Name $nsgRes.Name

    # Get NSG Rule named "WinRM_HTTPS" in the NSG attached to the NIC
    $CheckNSGRule = $nsg | Get-AzureRmNetworkSecurityRuleConfig -Name "WinRM_HTTPS" -ErrorAction SilentlyContinue

    # Check if the NSG Rule named "WinRM_HTTPS" already exists or not. If it already exists, skip, else create new rule with same name
    if (!$CheckNSGRule)
    {
        # Add the new NSG rule, and update the NSG
        $InboundRule = $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "WinRM_HTTPS" -Priority 1100 -Protocol TCP -Access Allow -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Direction Inbound -ErrorAction SilentlyContinue | Set-AzureRmNetworkSecurityGroup -ErrorAction SilentlyContinue
    }

    $NICs = Get-AzureRmNetworkInterface | Where-Object{$_.VirtualMachine.Id -eq $VM.Id}
    
    $IPConfigArray = New-Object System.Collections.ArrayList
    
    foreach($nic in $NICs)
    {
        if($nic.IpConfigurations.LoadBalancerBackendAddressPools)
        {
            $arr = $nic.IpConfigurations.LoadBalancerBackendAddressPools.id.Split('/')
            $LoadBalancerNameIndex = $arr.IndexOf("loadBalancers") + 1                    
            $loadBalancer = Get-AzureRmLoadBalancer | Where-Object{$_.Name -eq $arr[$LoadBalancerNameIndex]}
            $PublicIpId = $loadBalancer.FrontendIPConfigurations.PublicIpAddress.Id
        }

        $publicips = New-Object System.Collections.ArrayList

        if($nic.IpConfigurations.PublicIpAddress.Id)
        {
            $publicips.Add($nic.IpConfigurations.PublicIpAddress.Id) | Out-Null
        }

        if($PublicIpId)
        {
            $publicips.Add($PublicIpId) | Out-Null
        }

        foreach($publicip in $publicips)
        {
            $name = $publicip.split('/')[$publicip.Split('/').Count - 1]
            $ResourceGroup = $publicip.Split('/')[$publicip.Split('/').Indexof("resourceGroups")+1]
            $PublicIPAddress = Get-AzureRmPublicIpAddress -Name $name -ResourceGroupName $ResourceGroup | Select-Object -Property Name,ResourceGroupName,Location,PublicIpAllocationMethod,IpAddress
            $IPConfigArray.Add($PublicIPAddress) | Out-Null
        }
    }
    
    $Uri = $IPConfigArray | Where-Object{$_.IpAddress -ne $null} | Select-Object -First 1 -Property IpAddress

    if($Uri.IpAddress -ne $null)
    {               
        return $Uri.IpAddress.ToString()           
    }
    else
    {
        Write-Output "Couldnt get the IP Address of the VM"
        return
    }
}
else
{
    Write-Output "VM not found"
    return
}