# Process function Secrets passed in
$SECRETS_FILE = "/var/openfaas/secrets/vro-secrets"
$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event 
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

$vro = $SECRETS_CONFIG.VRO_SERVER;
$vroUser = $SECRETS_CONFIG.VRO_USERNAME;
$vroWorkflowID = $SECRETS_CONFIG.VRO_WORKFLOW_ID;
$vcenter = ($json.source -replace "https://","" -replace "/sdk","")

$separator = "object"," "
$option = [System.StringSplitOptions]::RemoveEmptyEntries
$FullFormattedMessage = $json.data.FullFormattedMessage.split($separator,$option)
$FullFormattedMessage = $FullFormattedMessage.split([Environment]::NewLine)

$vm = $FullFormattedMessage[$FullFormattedMessage.count-1]

if($env:function_debug -eq "true") {
    Write-Host "DEBUG: VRO=$vro"
    Write-Host "DEBUG: vm=$vroUser"
    Write-Host "DEBUG: vCenter=$vcenter"
    Write-Host "DEBUG: vmMoRef=$vmMoRef"
    Write-Host "DEBUG: vm=$vm"
    Write-Host "DEBUG: workflowID=$vroWorkflowID"
}
if($vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

$vroBody = @"
{
    "parameters":
	[
        {
            "value": {
                "sdk-object":{
                    "type": "VC:VirtualMachine",
                    "id": ""}
                },
            "type": "VC:VirtualMachine",
            "name": "$vm",
            "scope": "local"
        }
	]
}
"@

# Basic Auth for vRO execution
$pair = "$($SECRETS_CONFIG.VRO_USERNAME):$($SECRETS_CONFIG.VRO_PASSWORD)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"

$headers = @{
    "Authorization"="$basicAuthValue";
    "Accept="="application/json";
    "Content-Type"="application/json";
}

$vroUrl = "https://$($vro):443/vco/api/workflows/$($SECRETS_CONFIG.VRO_WORKFLOW_ID)/executions"

if($env:function_debug -eq "true") {
    Write-Host "DEBUG: TagCategory=$($SECRETS_CONFIG.TAG_CATEGORY_NAME)"
    Write-Host "DEBUG: TagName=$($SECRETS_CONFIG.TAG_NAME)"
    Write-Host "DEBUG: vRoURL=`"$($vroUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: body=$vroBody"
}

Write-Host "Synchronizing vSphere Tags to VM: $vm in NSX-T"
if($env:skip_vro_cert_check -eq "true") {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $vroBody -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Headers $headers -SkipHeaderValidation -Body $vroBody
}
