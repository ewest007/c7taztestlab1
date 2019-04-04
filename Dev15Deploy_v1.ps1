# Variables for common values
$rgName='testfoiaexpress-rg01'
$location='eastus'
$sqlserver1Name = "stestfxsql"
$app1startIp = "172.50.110.4"
$app1endIp = "172.50.110.50"
$database1Name = "foiadb"
$database2Name = "stestfxdb"
$sqlserver2Name = "stestedrsql"
$app2startIp = "172.50.120.4"
$app2endIp = "172.50.120.50"
$database3Name = "edrtestdb"
$database4Name = "s1edrtestdb"

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group.
New-AzureRmResourceGroup -Name $rgName -Location $location

# Create Storage Account for blob storage Standard_GRS
$storageaccount = New-AzureRmStorageAccount -ResourceGroupName $rgName -AccountName foiatestsa -Location eastus -SkuName Standard_GRS

# Create a virtual network with a App subnet, OCR subnet and EDR subnet.
$appsubnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'foiatest-app' -AddressPrefix '172.50.110.0/24'
$ocrsubnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'foiatest-ocr' -AddressPrefix '172.50.120.0/24'
$edrsubnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'foiatest-edr' -AddressPrefix '172.50.130.0/24'
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name 'foiatestvnet' -AddressPrefix '172.50.0.0/16' `
  -Location $location -Subnet $appsubnet, $ocrsubnet, $edrsubnet

# Create an NSG rule to allow HTTP traffic in from the Internet to the Web front-end subnet.
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'Allow-HTTPS-All' -Description 'Allow HTTPS' `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
  -SourceAddressPrefix 207.243.113.66/32 -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 443

# Create an NSG rule to allow RDP traffic from the Internet to the Web front-end subnet.
$rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'Allow-RDP-All' -Description "Allow RDP" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 `
  -SourceAddressPrefix 207.243.113.66/32 -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 3389

# Create a network security group for the Web front-end subnet.
$nsgapp = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
  -Name 'foiatestapp-nsg' -SecurityRules $rule1,$rule2

# Associate the APP NSG to the App subnet.
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'foiatest-app' `
  -AddressPrefix '172.50.110.0/24' -NetworkSecurityGroup $nsgapp

# Create a network security group for the OCR subnet.
$nsgocr = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
  -Name 'foiatestocr-nsg' -SecurityRules $rule2

# Associate the OCR NSG to the OCR subnet.
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'foiatest-ocr' `
  -AddressPrefix '172.50.120.0/24' -NetworkSecurityGroup $nsgocr

# Create a network security group for the EDR subnet.
$nsgedr = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
  -Name 'foiatestedr-nsg' -SecurityRules $rule2

# Associate the EDR NSG to the EDR subnet.
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'foiatest-edr' `
  -AddressPrefix '172.50.130.0/24' -NetworkSecurityGroup $nsgedr 

# Create a NIC for the App server 01 VM.
$nicVMapp01 = New-AzureRmNetworkInterface -ResourceGroupName $rgName -Location $location `
  -Name 'foiatestapp01nic' -NetworkSecurityGroup $nsgapp -Subnet $vnet.Subnets[0]

# Create App Server 01 VM in the app subnet
$vmConfig = New-AzureRmVMConfig -VMName 'foiatestapp01' -VMSize 'Standard_D4_v3' | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName 'foiatestapp01' -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  -Skus '2012-R2-Datacenter' -Version latest | Add-AzureRmVMNetworkInterface -Id $nicVMapp01.Id

$vmapp01 = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig

# Create a NIC for the OCR server 01 VM.
$nicVMocr01 = New-AzureRmNetworkInterface -ResourceGroupName $rgName -Location $location `
  -Name 'foiatestocr01nic' -NetworkSecurityGroup $nsgocr -Subnet $vnet.Subnets[1]

# Create OCR Server 01 VM in the OCR subnet
$vmConfig = New-AzureRmVMConfig -VMName 'foiatestocr01' -VMSize 'Standard_D4_v3' | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName 'c7tdev14-web02' -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  -Skus '2012-R2-Datacenter' -Version latest | Add-AzureRmVMNetworkInterface -Id $nicVMocr01.Id

$vmocr01 = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig

# Create a NIC for the EDR server 01 VM.
$nicVMedr01 = New-AzureRmNetworkInterface -ResourceGroupName $rgName -Location $location `
  -Name 'foiatestedr01nic' -NetworkSecurityGroup $nsgedr -Subnet $vnet.Subnets[2]

# Create EDR Server 01 VM in the EDR subnet
$vmConfig = New-AzureRmVMConfig -VMName 'foiatestedr01' -VMSize 'Standard_D4_v3' | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName 'foiatestedr01' -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' `
  -Skus '2012-R2-Datacenter' -Version latest | Add-AzureRmVMNetworkInterface -Id $nicVMedr01.Id

$vmedr = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig

# Create a SQL server 01 with a system wide unique server name
$sqlserver01 = New-AzureRmSqlServer -ResourceGroupName $rgName `
-ServerName $sqlserver1Name `
-Location $location `
-SqlAdministratorCredentials (Get-Credential)

# Create a server firewall rule that allows access from the specified IP range
$serverFirewallRule = New-AzureRmSqlServerFirewallRule -ResourceGroupName $rgName `
-ServerName $sqlserver1Name `
-FirewallRuleName "AllowedIPs" -StartIpAddress $app1startIp -EndIpAddress $app1endIp

# Create a blank database1 with an S3 performance level
$database = New-AzureRmSqlDatabase  -ResourceGroupName $rgName `
-ServerName $sqlserver1Name `
-DatabaseName $database1Name `
-RequestedServiceObjectiveName "S3"

# Create a blank database2 with an S0 performance level
$database = New-AzureRmSqlDatabase  -ResourceGroupName $rgName `
-ServerName $sqlserver1Name `
-DatabaseName $database2Name `
-RequestedServiceObjectiveName "S0"

# Create a SQL server 02 with a system wide unique server name
$sqlserver02 = New-AzureRmSqlServer -ResourceGroupName $rgName `
-ServerName $sqlserver2Name `
-Location $location `
-SqlAdministratorCredentials (Get-Credential)

# Create a server firewall rule that allows access from the specified IP range
$serverFirewallRule = New-AzureRmSqlServerFirewallRule -ResourceGroupName $rgName `
-ServerName $sqlserver2Name `
-FirewallRuleName "AllowedIPs" -StartIpAddress $app2startIp -EndIpAddress $app2endIp

# Create a blank database3 with an S2 performance level
$database = New-AzureRmSqlDatabase  -ResourceGroupName $rgName `
-ServerName $sqlserver2Name `
-DatabaseName $database3Name `
-RequestedServiceObjectiveName "S2"

# Create a blank database4 with an S0 performance level
$database = New-AzureRmSqlDatabase  -ResourceGroupName $rgName `
-ServerName $sqlserver2Name `
-DatabaseName $database4Name `
-RequestedServiceObjectiveName "S0"

# Create an NSG rule to block all outbound traffic from the back-end subnet to the Internet (must be done after VM creation)
$rule3 = New-AzureRmNetworkSecurityRuleConfig -Name 'Deny-Internet-All' -Description "Deny Internet All" `
  -Access Deny -Protocol Tcp -Direction Outbound -Priority 300 `
  -SourceAddressPrefix * -SourcePortRange * `
  -DestinationAddressPrefix Internet -DestinationPortRange *

# Add NSG rule to App NSG
$nsgapp.SecurityRules.add($rule3)

Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsgapp

# Add NSG rule to OCR NSG
$nsgocr.SecurityRules.add($rule3)

Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsgocr

# Add NSG rule to EDR NSG
$nsgedr.SecurityRules.add($rule3)

Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsgedr

# Add IIS to App01
Set-AzureRmVMExtension -ResourceGroupName $rgName `
    -ExtensionName "IIS" `
    -VMName "foiatestapp01" `
    -Location "EastUS" `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.8 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
        