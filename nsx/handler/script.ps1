# Process function Secrets passed in
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Test if PowerCLI Module is installed, install if not
if(Get-Module -ListAvailable -Name VMware.VimAutomation.Core) {
    Write-Host "Module exists"
} else {
    Write-Host "Module does not exist"
    Install-Package -Name VMware.VimAutomation.Core
}
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json

if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

# Process payload sent from vCenter Server Event
$vcenter = ($json.source -replace "https://","" -replace "/sdk","")

# Pull VM name from event message text and set it to variable.  
# Lots of work to accomodate spaces in a vm name. 
# Will break if message format from vSphere is changed in the future.
$separator = "object"
$FullFormattedMessage = $json.data.FullFormattedMessage
#write-host "FullFormattedMessage RAW="$FullFormattedMessage
$FullFormattedMessage.replace([Environment]::NewLine," ")
#write-host "FullFormattedMessage NewLine="$FullFormattedMessage
$pos = $FullFormattedMessage.IndexOf($separator)
#$leftPart = $FullFormattedMessage.Substring(0, $pos)
$rightPart = $FullFormattedMessage.Substring($pos+1)
#write-host "FullFormattedMessage leftPart="$leftPart
#write-host "FullFormattedMessage rightPart="$rightPart
$pos = $rightPart.replace("bject","")
$FormattedMessage = $pos.replace([Environment]::NewLine," ")
#write-host "FullFormattedMessage Split="$FullFormattedMessage
$FormattedMessage = $FormattedMessage.trim()
#write-host "FullFormattedMessage Complete="$FullFormattedMessage
$vm = $FormattedMessage

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

$vm = Get-VM -name $vm | Select-Object Name,PersistentId

# until uniquely identifiable VM data is provided in a vSphere event this is the only option to maintain a safe NSX-t operating environment
if($vm.PersistentID -is [array]) {
    Write-host "Machine" $vm.name[0] "is not unique in the vSphere instance.  Update NSX manually" 
    exit
}

$tags = Get-VM -name $vm.name | Get-TagAssignment

foreach ($tag in $tags)
{
    $tagString = $tag.tag.ToString()
    $tagArray = $tagString.split('/')
    $nsxList.add(@{"tag"=$tagArray[1];"scope"=$tagArray[0]})
    write-host $tagArray
    if($env:function_debug -eq "true") {
        write-host $tagString
    }
}

Write-Host "Disconnecting from vCenter Server ..."
Disconnect-VIServer * -Confirm:$false

$nsxJSON.add("external_id",$vm.PersistentId)
$nsxJSON.add("tags",$nsxList)

# Write nsxJSON to the NSX REST call Payload
$nsxBody = $nsxJSON | ConvertTo-Json -depth 10

# Create Basic Auth string for NSX authentication
$pair = "$($SECRETS_CONFIG.NSX_USERNAME):$($SECRETS_CONFIG.NSX_PASSWORD)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

# Render the NSX URL to POST VM Tag update
$nsxUrl = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?action=update_tags"

#URL Headers
$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}

if($env:debug_writehost -eq "true") {
    Write-Host "DEBUG: nsxURL=`"$($nsxUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxbody=`"$($nsxBody | Format-List | Out-String)`""
    Write-Host "DEBUG: Applying vSphere Tags for "$vm.name "to NSX-T"
}

# POST to NSX
if($env:skip_nsx_cert_check = "true") {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody
}