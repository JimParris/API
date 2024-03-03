Clear-Host

@'
GetDeviceInfo-Prompted.ps1

This script reads the Windows Agent config files to determine
its appliance ID and the fqdn of the N-Central server.  It then
prompts the user for credentials and queries the N-Central server
for device information.

It returns the device's name as displayed in N-Central, the
CustomerID the device is associated with, and the Customer Name.

Created by:	Jon Czerwinski, Cohn Consulting Corporation
Date:		November 10, 2013
Version:	1.0

'@

#
# Locate the Windows Agent Config folder
#
# By querying the Windows Agent Service path, the folder will be correctly identified
# even if it's not on the C: drive.
#
$AgentConfigFolder = (gwmi win32_service -Filter "Name like 'Windows Agent Service'").PathName
$AgentConfigFolder = $AgentConfigFolder.Replace('bin\agent.exe', 'config').Replace('"', '')

#
# Get the N-Central server out of the ServerConfig.xml file
#
function Get-NCentralSvr() {
	$ConfigXML = [xml](Get-Content "$Script:AgentConfigFolder\ServerConfig.xml")
	$ConfigXML.ServerConfig.ServerIP
}

#
# Get the device's ApplianceID out of the ApplianceConfig.xml file
#
function Get-ApplianceID() {
	$ConfigXML = [xml](Get-Content "$Script:AgentConfigFolder\ApplianceConfig.xml")
	$ConfigXML.ApplianceConfig.ApplianceID
}

#
# Determine who we are and where the N-Central server is
#
$serverHost = Get-NCentralSvr
$applianceID = Get-ApplianceID

#
# Get credentials
# We could read them as plain text and then create a SecureString from it
# By reading it as a SecureString, the password is obscured on entry
#
# We still have to extract a plain-text version of the password to pass to
# the API call.
#
$username = Read-Host 'Enter N-Central user id'
$secpasswd = Read-Host 'Enter password' -AsSecureString

$creds = New-Object System.Management.Automation.PSCredential ("\$username", $secpasswd)
$password = $creds.GetNetworkCredential().Password

$bindingURL = 'https://' + $serverHost + '/dms/services/ServerEI?wsdl'
$nws = New-WebServiceProxy $bindingURL -Credential $creds

#
# Feedback entered and discovered parameters
#
Write-Host
Write-Host "I am appliance - $applianceID - and my N-Central server is - $serverHost"
Write-Host "I will connect as $username with password $password"
Write-Host

#
# Set up and execute the query
#
$KeyPairs = @()

$KeyPair = New-Object Microsoft.PowerShell.Commands.NewWebserviceProxy.AutogeneratedTypes.WebServiceProxy1com_dms_services_ServerEI_wsdl.T_KeyPair
$KeyPair.Key = 'applianceID'
$KeyPair.Value = $applianceID
$KeyPairs += $KeyPair

$rc = $nws.deviceGet($username, $password, $KeyPairs)

<#
#
# Dump all device info
#
foreach ($device in $rc) {
	foreach ($item in $device.Info) {
		Write-Host $item.Key ":"
		Write-Host $item.Value
		Write-Host
		}
	}
#>

#
# Extract and return
#	N-Central device name
#	CustomerID
#	Customer Name
#
foreach ($device in $rc) {
	$DeviceInfo = @{}
	
	foreach ($item in $device.Info) {
		$DeviceInfo[$item.key] = $item.Value
 }

	Write-Host 'N-Central Device Name: ' $DeviceInfo['device.longname']
	Write-Host 'Customer ID:           ' $DeviceInfo['device.customerid']
	Write-Host 'Customer Name:         ' $DeviceInfo['device.customername']
	Write-Host
		
	Remove-Variable DeviceInfo
}
