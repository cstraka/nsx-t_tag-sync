# Test if PowerCLI Module is installed, install if not
if (Get-Module -ListAvailable -Name VMware.PowerCLI) {
    Write-Host "Module exists"
} else {
    Write-Host "Module does not exist"
    Install-Module -Name VMware.PowerCLI
}

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

# Process payload sent from vCenter Server Event
$vcenter = $SECRETS_CONFIG.vCenter_SERVER

$separator = "object"," "
$option = [System.StringSplitOptions]::RemoveEmptyEntries
$FullFormattedMessage = $json.data.FullFormattedMessage.split($separator,$option)
$FullFormattedMessage = $FullFormattedMessage.split([Environment]::NewLine)
$vm = $FullFormattedMessage[$FullFormattedMessage.count-1]

if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

#Assigning credentials securely
$userName = $SECRETS_CONFIG.vCenter_USERNAME
$password = convertto-securestring $SECRETS_CONFIG.vCenter_PASSWORD -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential $userName,$password

#connecting to VI server
Write-Host "Connecting to VI Server..."
Connect-VIServer -Server $vcenter -Protocol https -Credential $credentials

# Create the JSON Tagging structure for NSX
$nsxJSON = @{}
$nsxList = New-Object System.Collections.ArrayList

#Read VM tags from vCenter

$vmPersistentID = Get-VM -name $vm -server $vcenter | Select-object PersistentId
$tags = Get-VM -id $vmPersistentID -server $vcenter | Get-TagAssignment
 
foreach ($tag in $tags)
{
    $tagString = $tag.tag.ToString()
    $tagArray = $tagString.split('/')
    $nsxList.add(@{"tag"=$tagArray[1];"scope"=$tagArray[0]})
    if($env:function_debug -eq "true") {
        write-host $tagString
    }
}

Write-Host "Disconnecting from vCenter Server ..."
Disconnect-VIServer * -Confirm:$false

$nsxJSON.add("external_id",$vmPersistentID)
$nsxJSON.add("tags",$nsxList)

# Write nsxJSON to the NSX REST call Payload
$nsxBody = $nsxJSON | ConvertTo-Json -depth 10

# Create Basic Auth string for NSX authentication
$pair = "$($SECRETS_CONFIG.NSX_USERNAME):$($SECRETS_CONFIG.NSX_PASSWORD)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

# Authencticate to NSX
$nsxAuthURL = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?external_id=$vmPersistentID"
$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}

# Render the NSX URL to POST VM Tag update
$nsxUrl = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?action=update_tags"

if($env:debug_writehost -eq "true") {
    Write-Host "DEBUG: body=`"$($nsxAuthURL | Format-List | Out-String)`""
    Write-Host "DEBUG: body=`"$($body | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxURL=`"$($nsxUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxbody=`"$($nsxBody | Format-List | Out-String)`""
    Write-Host "DEBUG: Applying vSphere Tags for $vm to NSX-T"
}

# POST to NSX
if($env:skip_nsx_cert_check = "true") {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody
}