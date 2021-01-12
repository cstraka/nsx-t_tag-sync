Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in

#production inputs
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
$json = $args | ConvertFrom-Json

#if($env:prod_environment -ne "true") {
#    $SECRETS_FILE = "D:\OneDrive\GitHub\NSX-T_Tag-Sync\nsx\nsx-secrets.json"
#    $ARGS_FILE = "D:\OneDrive\GitHub\NSX-T_Tag-Sync\nsx\args.json"
#    $json = (Get-Content -Raw -Path $ARGS_FILE | ConvertFrom-Json)
#}

$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""

$vcenter = ($json.source -replace "https://","" -replace "/sdk","")
$vmMoRef = $json.data.vm.vm.value
$vm = $json.data.vm.name

#Assigning credentials securely
#$credentials = $host.ui.PromptForCredential("Input Your Virtual Center credentials", "Please enter your vCenter user name and password.", "", "NetBiosUserName")
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

$nsxUrl = "https://$($SECRETS_CONFIG.NSX_SERVER)/api/v1/fabric/virtual-machines?action=update_tags"

if($env:prod_environment -eq "true") {
    Write-Host "DEBUG: body=`"$($nsxAuthURL | Format-List | Out-String)`""
    Write-Host "DEBUG: body=`"$($body | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxURL=`"$($nsxUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: nsxbody=`"$($nsxBody | Format-List | Out-String)`""
    Write-Host "DEBUG: Applying vSphere Tags for $vm to NSX-T"
}

if($env:skip_nsx_cert_check -ne "true") {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $nsxUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $nsxbody
}