#Import-Module
Import-Module "$PSScriptRoot\SecureHadoopEnvironmentSetupTool.psd1" -ErrorAction Stop


#Setup Test Environment.
$SubscriptionId = "964c10bb-8a6c-43bc-83d3-6b318c6c7305"

$ClassicVNetResourceGroupName = "hditool4"
$ClassicVNetName = "hditool4advnet"

$ArmVNetResourceGroupName = "hditool45rg"
$ResourceManagerVNetName = "hditool45armvnet"
$ResourceManagerSubnetName =  "default"

$DomainName = "hditool4.onmicrosoft.com"
$ClusterUsersGroupDNs = "usergroup1"
$OrgUnitName = "HDI45OU"

$ResourceManagerVNetAddressPrefix = "10.45.0.0/16"
$ResourceManagerSubnetPrefix = "10.45.0.0/24"

Export-HDInsightRequiredConfiguration `
    -subscriptionId $SubscriptionId `
    -classicVNetResourceGroupName $ClassicVNetResourceGroupName `
    -classicVNetName $ClassicVNetName `
    -armVNetResourceGroupName $ArmVNetResourceGroupName `
    -resourceManagerVnetName $ResourceManagerVNetName `
    -resourceManagerSubnetName $ResourceManagerSubnetName `
    -resourceManagerVNetAddressPrefix $ResourceManagerVNetAddressPrefix `
    -resourceManagerSubnetPrefix $ResourceManagerSubnetPrefix `
    -domainName $DomainName `
    -OrganizationalUnitName $OrgUnitName `
    -clusterUsersGroupDNs $ClusterUsersGroupDNs 

