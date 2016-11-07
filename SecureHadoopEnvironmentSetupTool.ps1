. "$PSScriptRoot\Common\Common.ps1"
. "$PSScriptRoot\Azure\AzureHelper.ps1"
. "$PSScriptRoot\Common\Logger.ps1"

function Export-HDInsightRequiredConfiguration {
    #region parameters
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [parameter(Mandatory = $true)]
        [string]$ClassicVNetName,        
        [parameter(Mandatory = $true)]
        [string]$ClassicVNetResourceGroupName,        
        [parameter(Mandatory = $true)]
        [string]$ArmVNetResourceGroupName,
        [parameter(Mandatory = $true)]
        [string]$ResourceManagerVNetName,
        [parameter(Mandatory = $true)]
        [string]$ResourceManagerSubnetName,
        [parameter(Mandatory = $true)]
        [string]$ResourceManagerVNetAddressPrefix,
        [parameter(Mandatory = $true)]
        [string]$ResourceManagerSubnetPrefix,
        [parameter(Mandatory = $true)]
        [string]$DomainName,
        [parameter(Mandatory = $true)]
        [string]$OrganizationalUnitName,
        [parameter(Mandatory = $true)]
        [string]$ClusterUsersGroupDNs,
        [parameter(Mandatory = $false)]
        [switch] $Validate = $true
    )    
    #endregion
    
    Begin {
        ValidateGlobalArgument `
            -subscriptionId $SubscriptionId `
            -classicVNetName $ClassicVNetName `
            -classicVNetResourceGroupName $ClassicVNetResourceGroupName `
            -domainName $DomainName `
            -organizationalUnitName $OrganizationalUnitName `
            -clusterUsersGroupDNs $ClusterUsersGroupDNs `
            -armVNetResourceGroupName $ArmVNetResourceGroupName `
            -resourceManagerVNetName $ResourceManagerVNetName `
            -resourceManagerSubnetName $ResourceManagerSubnetName `
            -resourceManagerVNetAddressPrefix $ResourceManagerVNetAddressPrefix `
            -resourceManagerSubnetPrefix $ResourceManagerSubnetPrefix
    }
    
    Process {    

        try {

            ### STEP 1 - Login to Azure Classic 
            LoginAzureClassic -SubscriptionId $SubscriptionId
        

            ### STEP 2 - Get ClassicVNet Object  
            $actualClassicVNetName = "Group " +  $ClassicVNetResourceGroupName + " " + $ClassicVNetName
            $classicVNet = GetAzureVNetSite -classicVNetName $actualClassicVNetName 
            $location = $classicVNet.Location 


            ### STEP 3 - Login to Azure ARM
            LoginAzureRM -SubscriptionId $SubscriptionId 


            ### STEP 4 - Collect AAD Username/Password 
	        $domain_cred = Get-Credential –Message "Please type the name (Domain included) and password of an admin account that has permission to add the machine to the domain. Format: Domain\Username"
            $domainJoinAdminName = $domain_cred.UserName
            $domainJoinPassword = $domain_cred.Password 

            $stepIndex = 1


            ### STEP 5 - Create an ARM ResourceGroup 
            LogInfo "STEP $stepIndex of $Totalsteps"
            $stepIndex++
            ValidateResourceGroup -rgName $ArmVNetResourceGroupName -rgLocation $location
        

            ### STEP 6 - Create an ARM VNet
            LogInfo "STEP $stepIndex of $Totalsteps"
            $stepIndex++
            ValidateVNet -armRGName $ArmVNetResourceGroupName -resourceManagerVNetName $ResourceManagerVNetName -armVNetLocation $location -resourceManagerSubnetName $ResourceManagerSubnetName -addressPrefixVnet $ResourceManagerVNetAddressPrefix -addressPrefixSubnet $ResourceManagerSubnetPrefix -classicVNet $classicVNet


            ### STEP 7 - Peer ARM and Classic VNet 
            LogInfo "STEP $stepIndex of $Totalsteps"
            $stepIndex++
            $ClassicVNetResourceId = "/subscriptions/" + $SubscriptionId + "/resourceGroups/" + $ClassicVNetResourceGroupName + "/providers/Microsoft.ClassicNetwork/virtualNetworks/" + $ClassicVNetName
            PeerClassicARMVNet -resourceManagerVNetName $ResourceManagerVNetName -armRGName $ArmVNetResourceGroupName -resourceID $ClassicVNetResourceId -classicVNetName $ClassicVNetName

            if ($Validate) {

                LogInfo "Creating temporary resources for validation. `n" 

                LogInfo "STEP $stepIndex of $Totalsteps"
                $DynamicRGName | Out-File $Path 
                ValidateResourceGroup -rgName $DynamicRGName -rgLocation $location
            

                ## STEP 6 - Create Storage Account
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                $osDiskUri = CreateStorageAccount -location $location
     

                ### STEP 7 - Create VM
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                $armVNet = Get-AzureRmVirtualNetwork -ResourceGroupName $ArmVNetResourceGroupName -Name $ResourceManagerVNetName
                CreateARMVM -armVNet $armVNet -resourceManagerSubnetName $ResourceManagerSubnetName -location $location -osDiskUri $osDiskUri


                ### STEP 8 - Domain Join VM 
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                $vmName = $Token  + "vm" 
                $password= $domain_cred.GetNetworkCredential().Password
                DomainJoinVM -vmName $vmName -location $location -domainName $DomainName -domainJoinAdminName $domainJoinAdminName -domainJoinPassword $password


                ### STEP 9 - Create Organizational Unit
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                $trimmedLocation = $location -replace '\s', ''
                $dnsName = ($Token + "dnl." + $trimmedLocation + ".cloudapp.azure.com").ToLower()
                CreateOrganizationalUnit -vmFqdn $dnsName -domain $DomainName -organizationalUnitName $OrganizationalUnitName -organizationalUnitPath $OrganizationalUnitPath -domainJoinAdminName $domainJoinAdminName -domainJoinPassword $password -resourceManagerSubnetPrefix $ResourceManagerSubnetPrefix


                ## Generate JSON
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                GenerateJSON -armRGName $ArmVNetResourceGroupName -resourceManagerVNetName $ResourceManagerVNetName -domainName $DomainName -resourceManagerSubnetName $ResourceManagerSubnetName `
                            -ouName $OrganizationalUnitName -domainUsername $domain_cred.Username -domainUserPassword $password -clusterUsersGroupDNs $ClusterUsersGroupDNs

                ### Clean Up
                LogInfo "STEP $stepIndex of $Totalsteps"
                $stepIndex++
                DeleteResources -Status "Success" 
                
                ### Print Steps
                PrintSteps
            }

        } 
        catch {

            LogInfo "`n"
            Write-Error "There was an error encountered: "
            Write-Error $_.Exception.Message

            ### Clean Up
            DeleteResources -Status "Fail" 
                
            ### Print Steps
            PrintSteps

        }
   
    }
    
    End {
    }    
}

