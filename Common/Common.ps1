. "$PSScriptRoot\..\Azure\AzureHelper.ps1"
. "$PSScriptRoot\..\Common\Logger.ps1"

#Requires -RunAsAdministrator

#Global Variable
Set-Variable -Name g_ConfigFilePath -Value "$PSScriptRoot\..\config.json" -Scope Global
Set-Variable -Name Steps -Value (New-Object System.Collections.Generic.List[System.Object])  -Scope Global
Set-Variable -Name Asterisk -Value "****************************************************************************"  -Scope Global

#Constants 
Set-Variable -Name Token -Value (-join ((97..122) | Get-Random -Count 7 | % {[char]$_}))  -Option Constant 
Set-Variable -Name VNetNameSuffix -Value "vnet" -Option Constant
Set-Variable -Name ResourceGroupSuffix -Value "rg" -Option Constant
Set-Variable -Name OrganizationalUnitSuffix -Value "ou" -Option Constant
Set-Variable -Name SubnetName -Value "default" -Option Constant
Set-Variable -Name DynamicUpdate -Value "Secure" -Option Constant
Set-Variable -Name ReplicationScope -Value "Domain" -Option Constant
Set-Variable -Name DomainJoinExtensionName -Value "NewSecureHadoopJoinDomain" -Option Constant
Set-Variable -Name SecureHadoopPeeringName -Value "SecureHadoopPeering" -Option Constant
Set-Variable -Name AddressPrefixVnetDefault -Value "10.2.0.0/16" -Option Constant
Set-Variable -Name AddressPrefixSubnetDefault -Value "10.2.0.0/24" -Option Constant
Set-Variable -Name Path -Value "C:\ProgramData\SecureHadoopResources.txt" -Option Constant
Set-Variable -Name DynamicRGName -Value ($Token + $Token + $ResourceGroupSuffix) -Option Constant
Set-Variable -Name VMPassword -Value ((-join ((97..122) | Get-Random -Count 7 | % {[char]$_})) + "A1!") -Option Constant
Set-Variable -Name VMUser -Value "vmuser" -option Constant
Set-Variable -Name JSONFileName -Value "SecureHadoopConfig.json" -option Constant
Set-Variable -Name TotalSteps -Value 10 -option Constant


function ValidateGlobalArgument {
   param 
   (       
        [string]$SubscriptionId,
        [string]$classicVNetResourceGroupName,
        [string]$classicVNetName,            
        [string]$domainName,
        [string]$organizationalUnitName,
        [string]$clusterUsersGroupDNs,
        [string]$armVNetResourceGroupName,
        [string]$resourceManagerVNetName,
        [string]$resourceManagerSubnetName,
        [string]$resourceManagerVNetAddressPrefix,
        [string]$resourceManagerSubnetPrefix

   )
   LogInfo "ValidateGlobalArgument Started" 

   LogInfo "ValidateGlobalArgument completed"
}


function ValidateSubscriptionName {
    param
    (
        [string] $subscriptionName
    )
    
    $subscription = GetAzureSubscription -subscriptionName $subscriptionName

    if ($subscription) {        
        return $true
    }

    return $false
}


function ValidateResourceGroup {
    param 
    (
        [string] $rgName, 
        [string] $rgLocation
    )
    
    LogInfo "Validating Resource Group..."

    $resourceGroup = Get-AzureRmResourceGroup -Name $rgName -ErrorAction Ignore
    if (!$resourceGroup) {
        LogInfo ("Resource Group not found. Creating Resource Group : $rgName")
        New-AzureRmResourceGroup -Name $rgName -Location $rgLocation
        LogInfo ("Created Resource Group. Name is: $rgName")
        $Steps.Add("Created Resource Group (for ARM VNet): $rgName")
    }
    else {
        LogInfo "Resource Group VNet Validated."
        $Steps.Add("Validated Resource Group (for ARM Virtual Network) exists.")
    }

    LogInfo "`n"

}

function ValidateVNet {
    param 
    (
        [string] $armRGName, 
        [string] $resourceManagerVNetName, 
        [string] $armVNetLocation, 
        [string] $resourceManagerSubnetName, 
        [string] $addressPrefixVnet,
        [string] $addressPrefixSubnet,
        $classicVNet
    )
    
    LogInfo "Validating ARM VNet..."

    $armVNet = Get-AzureRmVirtualNetwork -ResourceGroupName $armRGName -Name $resourceManagerVNetName -ErrorAction Ignore
    if (!$armVNet) {

        LogInfo "ARM VNet not found. Creating ARM VNet : $resourceManagerVNetName"

        $classicVNet.AddressSpacePrefixes[0] -match "\d{1,3}\.\d{1,3}"
        
        $dns0 = "" + $matches[0] + ".0.4"
        $dns1 = "" + $matches[0] + ".0.5"

	    $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $armRGName -Name $resourceManagerVNetName -AddressPrefix $addressPrefixVnet -Location $armVNetLocation -DnsServer $dns0, $dns1
        LogInfo "Created ARMVNet : $resourceManagerVNetName"
        $Steps.Add("Created ARM VNet: $resourceManagerVNetName")

        LogInfo "Adding SubnetConfig"
	    Add-AzureRmVirtualNetworkSubnetConfig -Name $resourceManagerSubnetName -VirtualNetwork $vnet -AddressPrefix $addressPrefixSubnet	
	    Set-AzureRmVirtualNetwork -VirtualNetwork $vnet 
        LogInfo "Created Subnet : $resourceManagerSubnetName"
        $Steps.Add("Created ARM Subnet: $resourceManagerSubnetName")
    }
    else {
        LogInfo "ARM VNet Validated."
        $Steps.Add("Validated that ARM Virtual Network exists: $resourceManagerVNetName")
    }

    LogInfo "`n"

}

function PeerClassicARMVNet {
    param
    (
        [string] $resourceManagerVNetName,
        [string] $armRGName,  
        [string] $resourceID,
        [string] $classicVNetName
    )
    
    LogInfo "Peering VNets."
    LogInfo "Might take a few seconds."

    $checkPeered = Get-AzureRmVirtualNetworkPeering -Name $SecureHadoopPeeringName -VirtualNetworkName $resourceManagerVNetName -ResourceGroupName $armRGName -ErrorAction Ignore

    if (!$checkPeered) {
        
        LogInfo "Peering not found. Peering VNet : $SecureHadoopPeeringName"

        $armVNet = Get-AzureRmVirtualNetwork -ResourceGroupName $armRGName -Name $resourceManagerVNetName

        ### Register VNets
        Register-AzureRmProviderFeature -FeatureName AllowVnetPeering -ProviderNamespace Microsoft.Network
	    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network	
		
	    ### Link between VNets 	
        Add-AzureRmVirtualNetworkPeering -Name $SecureHadoopPeeringName -VirtualNetwork $armVNet -RemoteVirtualNetworkId $resourceID 
        
        LogInfo "VNets Peered.`n"
        $Steps.Add("Peered Classic VNET and ARM VNet.")
    }
    else {
        LogInfo "Validated Virtual Network peering.`n"
        $Steps.Add("Validated Virtual Network peering between $classicVNetName and $resourceManagerVNetName exists.")
    }

}


function CreateStorageAccount 
{
    param
    ( 
        [string] $location
    )
    
    LogInfo "Creating Storage Account." 

    $stgName = $Token + "stg"

    $stgAccount = Get-AzureRmStorageAccount -ResourceGroupName $DynamicRGName -Name $stgName -ErrorAction Ignore
    if (!$stgAccount) {
        $stgAccount = New-AzureRmStorageAccount -ResourceGroupName $DynamicRGName -Name $stgName -SkuName "Standard_LRS" -Kind "Storage" -Location $location
    }
    $blobPath = "vhds/WindowsVMosDisk.vhd"
    $osDiskUri = $stgAccount.PrimaryEndpoints.Blob.Tostring() + $blobPath

    LogInfo ("Storage Account Created. Name is $stgName `n") 

    return $osDiskUri

}


function CreateARMVM 
{
    param
    (
        $armVNet, 
        [string] $resourceManagerSubnetName, 
        [string] $location, 
        [string] $osDiskUri
    )
    
    LogInfo "Creating VM." 

    $vmName = $Token  + "vm" 
    $computerName = $Token + "comp"

    $getVM = Get-AzureRmVM -ResourceGroupName $DynamicRGName -Name $vmName -ErrorAction Ignore 

    $securePassword = ConvertTo-Securestring $VMPassword -AsPlainText -Force
    $vm_cred = New-Object System.Management.Automation.PSCredential ($VMUser, $securePassword)

    if (!$getVM) {

        LogInfo "This step might take up to 10 minutes..." 

        ### Set administrator account name and password for VM
        $securePassword = ConvertTo-Securestring $VMPassword -AsPlainText -Force
        $vm_cred = New-Object System.Management.Automation.PSCredential ($VMUser, $securePassword)

        ### VM Configuration and Creation 
	    $vm = New-AzureRmVMConfig -VMName $vmName -VMSize "Standard_A1" 
	    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $computerName -Credential $vm_cred -ProvisionVMAgent -EnableAutoUpdate
	    $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"

        $subnetObject = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $armVNet -Name $resourceManagerSubnetName
        
        $dnl = $Token + "dnl"
        $pipName = $Token + "ipaddress" 
        $pip = New-AzureRmPublicIpAddress -Name $pipName -ResourceGroupName $DynamicRGName -DomainNameLabel $dnl -Location $location -AllocationMethod Dynamic

        $nicName = $Token + "nic"
        $nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $DynamicRGName -Location $location -SubnetId $subnetObject.Id -PublicIpAddressId $pip.Id
                
        $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id 

        $diskName = $Token + "windowsvmosdisk"
        $vm = Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage
	    New-AzureRmVM -ResourceGroupName $DynamicRGName -Location $location -VM $vm
    }

    LogInfo ("VM Created. VM Name is $vmName `n")

    return $vm_cred

}


function DomainJoinVM 
{
    param
    (
        [string] $vmName, 
        [string] $location, 
        [string] $domainName,
        [string] $domainJoinAdminName, 
        [string] $domainJoinPassword
    )

    LogInfo "Domain-Joining VM." 

    $getExtension = Get-AzureRmVMExtension -ResourceGroupName $DynamicRGName -VMName $vmName -Name $DomainJoinExtensionName -ErrorAction Ignore
    
    if (!$getExtension -or ($getExtension.ProvisioningState -ne "Succeeded"))
    {
        LogInfo "This step might take up to 3 minutes..." 
        Set-AzureRMVMExtension `
            -VMName $vmName `
            –ResourceGroupName $DynamicRGName `
            -Name $DomainJoinExtensionName `
            -ExtensionType "JsonADDomainExtension" `
            -Publisher "Microsoft.Compute" `
            -TypeHandlerVersion "1.0" `
            -Location $location `
            -Settings @{ "Name" = $domainName; "OUPath" = ""; "User" = $domainJoinAdminName; "Restart" = "true"; "Options" = 3} `
            -ProtectedSettings @{"Password" = $domainJoinPassword}
    }

    LogInfo "VM is domain-joined. `n"
}


function CreateOrganizationalUnit 
{
    param
    (
        [string] $vmFqdn,
        [string] $domain,
        [string] $organizationalUnitName,
        [string] $domainJoinAdminName, 
        [string] $domainJoinPassword,
        [string] $resourceManagerSubnetPrefix
    )

    LogInfo "Creating Organizational Unit." 
    LogInfo "This step might take up to 5 minutes..." 

    $secureDomainPassword = ConvertTo-Securestring $domainJoinPassword -AsPlainText -Force 
    $aad_cred =  New-Object System.Management.Automation.PSCredential($domainJoinAdminName, $secureDomainPassword)
    $ouPath = "DC=" + $domain.Replace(".", ",DC=")

    ### Set up Remote Powershell 
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $vmFqdn -Force
    Start-Sleep -s 60
    $session = New-PSSession -ComputerName $vmFqdn -Credential $aad_cred   

    Invoke-Command -Session $session -ScriptBlock {import-module servermanager} 
    Invoke-Command -Session $session -ScriptBlock {Add-WindowsFeature -Name “RSAT-AD-PowerShell” -IncludeAllSubFeature} 
    Invoke-Command -Session $session -ScriptBlock {Start-Sleep -s 15} 
    Invoke-Command -Session $session -ScriptBlock {import-module activedirectory} 
    Invoke-Command -Session $session -ScriptBlock {$remoteOUName = $using:organizationalUnitName} 
    Invoke-Command -Session $session -ScriptBlock {$ouObject = Get-ADOrganizationalUnit -Filter 'Name -eq $remoteOUName' -Credential $using:aad_cred  -ErrorAction Ignore}
    Invoke-Command -Session $session -ScriptBlock {if (!$ouObject) {New-ADOrganizationalUnit -Name $remoteOUName -Path $using:ouPath -Credential $using:aad_cred}} 
    
    LogInfo "Organizational Unit Created.`n"
    $ouNameFull = "OU=" + $organizationalUnitName + ",DC=" + $domain.Replace(".", ",DC=")
    $Steps.Add("Created Organizational Unit: $ouNameFull")

    ### Reverse Dns Zone 

    $networkId = $resourceManagerSubnetPrefix.Substring(0, $resourceManagerSubnetPrefix.LastIndexOf(".")).Split(".")
    [array]::Reverse($networkId)
    $reverseNetworkId = $networkId -join "."

    LogInfo "Creating ReverseDns Zone"
    LogInfo "This step might take up to 5 minutes..."

    Invoke-Command -Session $session -ScriptBlock {Add-WindowsFeature -Name “RSAT” -IncludeAllSubFeature} 
    Invoke-Command -Session $session -ScriptBlock {$cimSession = New-CimSession -Credential $using:aad_cred}
    Invoke-Command -Session $session -ScriptBlock {$zoneName = $using:reverseNetworkId + ".in-addr.arpa"}
    Invoke-Command -Session $session -ScriptBlock {$dnsServerObject = Get-DnsServerZone -ComputerName $using:domain -CimSession $cimSession -Name $zoneName  -ErrorAction Ignore}
    Invoke-Command -Session $session -ScriptBlock {if (!$dnsServerObject) {Add-DnsServerPrimaryZone -ComputerName $using:domain -CimSession $cimSession -NetworkID $using:resourceManagerSubnetPrefix -ReplicationScope $using:ReplicationScope -DynamicUpdate $using:DynamicUpdate}}
            
    LogInfo "Reverse Dns Zone Created"
    $Steps.Add("Created Reverse DNS Zone: $NetworkId")

}


function DeleteResources 
{
    param
    (
        [string] $Status
    )
    
    LogInfo "Some temporary resources were created in the following Resource Group: $DynamicRGName"
    LogInfo "Deleting Temporary Resources."
    $pathExists = Test-Path $path

    if ($pathExists -eq $True) {
        $resourcesName = Get-Content $path 
        foreach ($name in $resourcesName)
        {
            $dynamicRG = Get-AzureRmResourceGroup -Name $name -ErrorAction Ignore
            if ($dynamicRG) {
                LogInfo "This step might take up to 5 minutes..." 
                Remove-AzureRmResourceGroup -Name $name -Force
            }
        }
    }
    LogInfo "Temporary Resources Deleted. `n" 

    if ($Status -ne "Fail") {
        
        $path = (Get-Item -Path ".\" -Verbose).FullName + "\$JSONFileName"
        LogInfo $asterisk
        LogInfo $asterisk
        LogInfo "NEXT STEPS: "
        LogInfo "The tool has generated the JSON config, located in current folder: " 
        LogInfo $path
        LogInfo "Please upload to Azure portal and create a cluster." 
        LogInfo $asterisk 
    }

}

function PrintSteps 
{
    LogInfo $asterisk
    LogInfo $asterisk
    LogInfo "Following steps were executed: `n"

    foreach ($step in $Steps)
    {
        LogInfo $step
    }

    LogInfo $asterisk
    LogInfo $asterisk
}

 

function GenerateJSON {
    param 
    (
        [string] $armRGName, 
        [string] $resourceManagerVNetName, 
        [string] $domainName, 
        [string] $resourceManagerSubnetName,
        [string] $ouName,
        [string] $domainUsername,
        [string] $domainUserPassword,
        [string] $clusterUsersGroupDNs
    )
    
    LogInfo "Generating JSON."

    $aVNet = Get-AzureRmVirtualNetwork -ResourceGroupName $armRGName -Name $resourceManagerVNetName
    $aSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $aVNet -Name $resourceManagerSubnetName
    $ouNameFull = "OU=" + $ouName + ",DC=" + $domainName.Replace(".", ",DC=")

    $startIndex = $domainUsername.IndexOf("\")
    $userName = $domainUserName.Substring($startIndex + 1) + "@" + $domainName

    $config = 
    @{
        schema         = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#";
        contentVersion  = "1.0.0.0";
        parameters      = 
            @{
                virtualNetworkId     = @{ value = $aVNet.Id};
                virtualNetworkSubnet = @{ value = $aSubnet.Id};
                domain               = @{ value = $domainName};
                organizationalUnitDN = @{ value = $ouNameFull};
                ldapsUrls            = @{ value = @("ldaps://" + $domainName + ":636")}; 
                domainUsername       = @{ value = $userName};
                domainUserPassword   = @{ value = $domainUserPassword};
                clusterUsersGroupDNs = @{ value = @($clusterUsersGroupDNs)};
             } 
     }
    
    $config | ConvertTo-Json -Compress -Depth 3| Out-File -encoding "UTF8" -FilePath  ".\$JSONFileName"


    LogInfo "JSON Generated."
    LogInfo "`n"

}

function LoginAzureClassic
{
    param
    (        
        [string] $SubscriptionId
    )

    LogInfo "Validating Classic Login."

    Add-AzureAccount 
    Select-AzureSubscription -SubscriptionId $SubscriptionId -Current 

    LogInfo "Login Validated."

}

function LoginAzureRM
{
    param
    (        
        [string] $SubscriptionId
    )

    LogInfo "Validating RM Login."

    Login-AzureRmAccount
    Set-AzureRmContext -SubscriptionId $SubscriptionId 

    LogInfo "Login Validated."
    
}


