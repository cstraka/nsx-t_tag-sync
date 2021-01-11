Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in

#production inputs
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
#Testing Secrets Input Location
$SECRETS_FILE = "D:\OneDrive\GitHub\NSX-T_Tag-Sync\nsx\nsx-secrets.json"

$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

$vcenter = ($json.source -replace "https://","" -replace "/sdk","");
$vmMoRef = $json.data.vm.vm.value;
$vm = $json.data.vm.name;

#Assigning credentials securely
#$credentials = $host.ui.PromptForCredential("Input Your Virtual Center credentials", "Please enter your vCenter user name and password.", "", "NetBiosUserName")
$credentials = New-object System.Management.Automation.PSCredential($SECRETS_CONFIG.vCenter_USERNAME,$SECRETS_CONFIG.vCenter_PASSWORD)

#connecting to VI server
Connect-VIServer -Server $vcenter -Protocol https -Credential $credentials

if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

# e.g. mgmt-vcsa-01.cpbu.corp/vm-2660
$nsxVmId = "$vcenter/$vmMoRef"

$jsonTags = @{}
$nsxTags = @{}

$vmList = New-Object System.Collections.ArrayList
$tagList = New-Object System.Collections.ArrayList
$nsxList = New-Object System.Collections.ArrayList

$tags = Get-VM -name $vm -server $vcenter | Get-TagAssignment
$vmID = Get-VM -name $vm -server $vcenter
$vmPersistentID = $vmID.PersistentId
foreach ($tag in $tags)
{
    $tagString = $tag.tag.ToString()
    $tagArray = $tagString.split('/')
    $tagList.add(@{"scope"=$tagArray[0];"tag"=$tagArray[1]})
    $nsxList.add(@{"tag"=$tagArray[1];"scope"=$tagArray[0]})
}
$vmList.add(@{"viServer"=$vcenter;"name"=$vm;"vmPersisitentID"=$vmID.PersistentID;"vmID"=$vmID.Id;"tags"=$tagList;})
$jsonTags.add("data",$vmList)

$jsonTags | ConvertTo-Json -depth 10 | Out-File "d:\virtualmachines.json"
$body = $jsonTags | ConvertTo-Json -depth 10
#write-host $jsonBody

#Write-Host "Disconnecting from vCenter Server ..."
Disconnect-VIServer * -Confirm:$false

$nsxTags.add("external_id",$vmPersistentID)
$nsxTags.add("tags",$nsxList)

$nsxTags | ConvertTo-Json -depth 10 | Out-File "d:\NSX-virtualmachines.json"
$nsxBody = $nsxTags | ConvertTo-Json -depth 10

# Basic Auth for nsx execution
$pair = "$($SECRETS_CONFIG.NSX_USERNAME):$($SECRETS_CONFIG.NSX_PASSWORD)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

$nsxAuthURL = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?external_id=$vmPersistentID"
$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}
$authResponse = Invoke-WebRequest -uri $nsxAuthURL -Method GET -Headers $headers -SkipHeaderValidation -SkipCertificateCheck

$nsxUrl = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?action=update_tags"

$env:function_debug = 'false'
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: body=`"$($body | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxURL=`"$($nsxUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxbody=`"$($nsxBody | Format-List | Out-String)`""
    Write-Host "DEBUG: Applying vSphere Tags for $vm to NSX-T"
}

$env:skip_nsx_cert_check = 'true'

if($env:skip_nsx_cert_check -eq "true") {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody
}