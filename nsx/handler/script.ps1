Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in

#production inputs
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
$json = $args | ConvertFrom-Json

if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
    $arguments = $json.Arguments
    foreach ($argument in $arguments) {
        Write-Host "DEBUG: argument=`"$($argument | Format-List | Out-String)`""
    }
}

$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$vcenter = $SECRETS_CONFIG.vCenter_SERVER
$vmMoRef = $json.data.vm.vm.value
$vm = $json.data.vm.name

#Assigning credentials securely
$userName = $SECRETS_CONFIG.vCenter_USERNAME
$password = convertto-securestring $SECRETS_CONFIG.vCenter_PASSWORD -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential $userName,$password

#connecting to VI server
Connect-VIServer -Server $vcenter -Protocol https -Credential $credentials

if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

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

if($env:development_environment -eq "true") {
    $jsonTags | ConvertTo-Json -depth 10 | Out-File "d:\virtualmachines.json"
} else {
    $jsonTags | ConvertTo-Json -depth 10
}
$body = $jsonTags | ConvertTo-Json -depth 10

#Write-Host "Disconnecting from vCenter Server ..."
Disconnect-VIServer * -Confirm:$false

$nsxTags.add("external_id",$vmPersistentID)
$nsxTags.add("tags",$nsxList)

if($env:development_environment -eq "true") {
    $nsxTags | ConvertTo-Json -depth 10 | Out-File "d:\NSX-virtualmachines.json"
} else {
    $nsxTags | ConvertTo-Json -depth 10
}
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

$nsxUrl = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?action=update_tags"

if($env:debug_writehost -eq "true") {
    Write-Host "DEBUG: body=`"$($nsxAuthURL | Format-List | Out-String)`""
    Write-Host "DEBUG: body=`"$($body | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxURL=`"$($nsxUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxbody=`"$($nsxBody | Format-List | Out-String)`""
    Write-Host "DEBUG: Applying vSphere Tags for $vm to NSX-T"
}

if($env:skip_nsx_cert_check = "true") {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody
}