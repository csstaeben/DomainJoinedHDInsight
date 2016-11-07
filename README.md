# DomainJoinedHDInsight
Configuration tool to setup domain joined HDInsight clusters



To edit the PowerShell script

Open run.ps1 using Windows PowerShell ISE or any text editor.
Fill the values for the following variables:


$SubscriptionId – The ID of the Azure subscription where you want to create your HDInsight cluster. You have already created a Classic virtual network in this subscription, and will be creating an Azure Resource Manager virtual network for the HDInsight cluster under subscription.#

$ClassicVNetName - The classic virtual network which contains the Azure AD DS. This virtual network must be in the same subscription which is provided above. This virtual network must be created using the Azure portal, and not using classic portal. If you follow the instruction in Configure Domain-joined HDInsight clusters (Preview), the default name is contosoaadvnet.

$ClassicResourceGroupName – The Resource Manager group name for the classic virtual network that is mentioned above. For example contosoaadrg.

$ArmResourceGroupName – The resource group name within which, you want to create the HDInsight cluster. You can use the same resource group as $ArmResourceGroupName. If the resource group does not exist, the script creates the resource group.

$ArmVNetName - The Resource Manager virtual network name within which you want to create the HDInsight cluster. This virtual network will be placed into $ArmResourceGroupName. If the VNet does not exist, the PowerShell script will create it. If it does exist, it should be part of the resource group that you provide above.

$AddressVnetAddressSpace – The network address space for the Resource Manager virtual network. Ensure that this address space is available. This address space cannot overlap the classic virtual network’s address space. For example, “10.1.0.0/16”

$ArmVnetSubnetName - The Resource Manager virtual network subnet name within which you want to place the HDInsight cluster VMs. If the subnet does not exist, the PowerShell script will create it. If it does exist, it should be part of the virtual network that you provide above.

$AddressSubnetAddressSpace – The network address range for the Resource Manager virtual network subnet. The HDInsight cluster VM IP addresses will be from this subnet address range. For example, “10.1.0.0/24”.

$ActiveDirectoryDomainName – The Azure AD domain name that you want to join the HDInsight cluster VMs to. For example, “contoso.onmicrosoft.com”

$ClusterUsersGroups – The common name of the security groups from your AD that you want to sync to the HDInsight cluster. The users within this security group will be able to log on to the cluster dashboard using their active directory domain credentials. These security groups must exist in the active directory. For example, “hiveusers” or “clusteroperatorusers”.

$OrganizationalUnitName - The organizational unit in the domain, within which you want to place the HDInsight cluster VMs and the service principals used by the cluster. The PowerShell script will create this OU if it does not exist. For example, “HDInsightOU”.
Save the changes.

To run the script

Run Windows PowerShell as administrator.
Browse to the folder of run.ps1.
Run the script by typing the file name, and hit ENTER. It pops up 3 sign-in dialogs:

Sign in to Azure classic portal – Enter your credentials which you use to sign in to Azure classic portal. You must have created the Azure AD and Azure AD DS using these credentials.
Sign in to Azure Resource Manager portal – Enter your credentials which you use to sign in to Azure Resource Manager portal.
Domain user name – Enter the credentials of the Domain user name that you want to be an admin on the HDInsight cluster. If you created an Azure AD from scratch, you must have created this user using this documentation.
Important:
Enter the username in this format:

Domainname\username (for example contoso.onmicrosoft.com\clusteradmin)

This user must have 3 privileges: To join machines to the provided Active Directory domain; to create service principals and machine objects within the provided Organizational Unit; and to add reverse DNS proxy rules.
