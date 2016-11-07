. "$PSScriptRoot\..\Common\Logger.ps1"

function GetAzureSubscription {
    param
    (
        [String] $subscriptionId
    )
    
    $subscription = Get-AzureRmSubscription -SubscriptionId $subscriptionId
}

function SelectAzureSubscription {
    param
    (
        [String] $subscriptionId
    )
    
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
}

function GetAzureResourceGroup {

    param
    (   
        [PSObject] $name
    )

    return Get-AzureRmResourceGroup -Name $name
}

function GetSubnetId {

 param
    (   
        [String] $resourceGroupName,     
        [String] $vNetName,
        [String] $subnetName
    )
        
    $vNet = GetAzureResource  -resourceType "Microsoft.Network/virtualNetworks" -resourceGroupName $resourceGroupName -resourceName $vNetName

    if (!$vNet) {
        LogError "Can not find VirtualNetwork: $vNetName in ResourceGroup: $resourceGroupName"
        return $false
    }

    foreach ($subNet in $vNet.Properties.Subnets) {
        if ([string]::Equals($subNet.Name, $subnetName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $subNet.Id
        }
    }

    LogError "Invalid subNet Name ResourceGroup: $resourceGroupName virtualNetworkName: $vNetName SubnetName: $subnetName"

    return $null
}

function FindAzureResource {

param
    (   
        [String] $resourceTagName,     
        [String] $resourceTagValue
    )

    return Find-AzureRmResource -TagName $ResourceTagName -TagValue $ResourceTagValue
}

function GetAzureResourceBasedOnType {

param
    (   
        [Object[]] $resources,
        [String] $resourceType
    )

    return $resources | Where-Object {[string]::Equals($_.ResourceType, $resourceType, [System.StringComparison]::OrdinalIgnoreCase)} 

}

function RemoveDependentArmResources {

param
    (   
        [Object[]] $resources
    )

    $dependencyList = @('Microsoft.Compute/virtualMachines/extensions'
                                'Microsoft.Compute/virtualMachines'
                                'Microsoft.Network/networkInterfaces'
                                'Microsoft.Network/publicIPAddresses')

    foreach ($resourceType in $dependencyList) {
        $resourcesToDelete = GetAzureResourceBasedOnType -resources $resources -resourceType $resourceType
        if ($resourcesToDelete) {
            $armResourceIds = $resourcesToDelete | Select-Object -ExpandProperty ResourceId
            DeleteArmResources($armResourceIds)
        }
    }
}

function DeleteArmResources {

param
    (   
        [String[]] $armResourceIds
    )

    if ($armResourceIds) {
        foreach ($armResourceId in $armResourceIds) {
        Write-Information "Deleting Resource $armResourceId." 
        Remove-AzureRmResource -ResourceId $armResourceId  -Force -Verbose
        Write-Information "$armResourceId Resource deleted."
        }
    }
}

function GetNetworkInfo {
        
    Get-AzureVM | Format-List Name, IPAddress, DNSName
}

function GetAzureResource {
    param
    (        
        [String] $resourceGroupName,
        [String] $resourceName,
        [String] $resourceType        
    )

    return Get-AzureRmResource -ResourceType $resourceType -ResourceGroupName $resourceGroupName -ResourceName $resourceName
}

function GetAzureStorageAccount {
    param
    (        
        [String] $resourceGroupName,
        [String] $storageAccountName
    )

    return Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
}

function GetAzureVNetSite {
    param
    (        
        [String] $classicVNetName
    )

    return Get-AzureVNetSite -VNetName $classicVNetName 
}

function CheckAzureRMSession () {
    $Error.Clear()
    
    LogVerbose "Validating Login"
    
    $output = Get-AzureRmContext -ErrorAction Continue
    if ([String]::IsNullOrEmpty($output)) {
        $output = (Add-AzureRmAccount -ErrorAction Stop)
    }
    LogVerbose $output
    foreach ($eacherror in $Error) {
        if ($eacherror.Exception.ToString() -like "*Run Login-AzureRmAccount to login.*") {
            Write-Host "Error while login"
        }
    }

    LogVerbose "Login Validated"
    $Error.Clear();
}

