Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in

#production inputs
$SECRETS_FILE = "/var/openfaas/secrets/vro-secrets"
#Testing Secrets Input Location
$SECRETS_FILE = "D:\OneDrive\GitHub\NSX-T_Tag-Sync\vro\vro-secrets.json"

$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

$vcenter = ($json.source -replace "https://","" -replace "/sdk","");
$vmMoRef = $json.data.vm.vm.value;
$vm = $json.data.vm.name;

$vcenter = "vcenter7-phx.itplab.local"
$vmMoRef = "vm-1086"
$vm = "blue-app202"

#Assigning credentials securely
$credentials = $host.ui.PromptForCredential("Input Your Virtual Center credentials", "Please enter your vCenter user name and password.", "", "NetBiosUserName")

#connecting to VI server
Connect-VIServer -Server $vcenter -Protocol https -Credential $credentials

if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

# e.g. mgmt-vcsa-01.cpbu.corp/vm-2660
$vroVmId = "$vcenter/$vmMoRef"

$jsonTags = @{}
$vmList = New-Object System.Collections.ArrayList
$tagList = New-Object System.Collections.ArrayList
$tags = Get-VM -name $vm -server $vcenter | Get-TagAssignment
$vmID = Get-VM -name $vm -server $vcenter
foreach ($tag in $tags)
{
    $tagString = $tag.tag.ToString()
    $tagArray = $tagString.split('/')
    $tagList.add(@{"category"=$tagArray[0];"value"=$tagArray[1]})
}
$vmList.add(@{"viServer"=$vcenter;"name"=$vm;"vmPersisitentID"=$vmID.PersistentID;"vmID"=$vmID.Id;"tags"=$tagList;})
$jsonTags.add("data",$vmList)

$jsonTags | ConvertTo-Json -depth 10 | Out-File "d:\virtualmachines.json"
$jsonBody = $jsonTags | ConvertTo-Json -depth 10
#write-host $jsonBody
$body = $jsonBody #| ConvertFrom-Json
Write-Host $body
#Write-Host "Disconnecting from vCenter Server ..."
Disconnect-VIServer * -Confirm:$false

# Basic Auth for vRO execution
#$pair = "svc_vco@itplab.local:Passw0rd!"
$pair = "$($SECRETS_CONFIG.VRO_USERNAME):$($SECRETS_CONFIG.VRO_PASSWORD)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

$vroAuthURL = "https://$($SECRETS_CONFIG.VRO_SERVER):443/vco/api/workflows"
$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}
$authResponse = Invoke-WebRequest -uri $vroAuthURL -Method GET -Headers $headers -SkipHeaderValidation -SkipCertificateCheck

$vroUrl = "https://$($SECRETS_CONFIG.VRO_SERVER):443/vco/api/workflows/$($SECRETS_CONFIG.VRO_WORKFLOW_ID)/executions"
$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}

$env:function_debug = 'true'
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: vRoVmID=$vroVmId"
    Write-Host "DEBUG: vRoURL=`"$($vroUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: body=$body"
}

$env:skip_vro_cert_check = 'true'

if($env:skip_vro_cert_check -eq "true") {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $body -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $body
}