
# Process function Secrets passed in
$SECRETS_FILE = "/var/openfaas/secrets/vro-secrets"
$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

if($env:function_debug -eq "true") {
    $arguments = $json.Arguments
    Write-Host $json.Arguments
    Write-Host "Arguments= "
    foreach($argument in $arguments) {
        Write-Host $argument
    }
}

$vcenter = ($json.source -replace "https://","" -replace "/sdk","");
$vmMoRef = $json.data.vm.vm.value;

$separator = "object"," "
$option = [System.StringSplitOptions]::RemoveEmptyEntries
$FullFormattedMessage = $json.data.FullFormattedMessage.split($separator,$option)
$FullFormattedMessage = $FullFormattedMessage.split([Environment]::NewLine)
$vm = $FullFormattedMessage[$FullFormattedMessage.count-1]


if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

# e.g. mgmt-vcsa-01.cpbu.corp/vm-2660
$vroVmId = "$vcenter/vm-1086"

# This syntax is very specific.
$vroBody = @"
{
    "parameters": [
        {
            “type”: “string”,
            “name”: “vroBody”,
            “scope”: “local”,
            “value”: {
                “string”: {
                    “value”: “$vm”
                }
            }
        },
        {
            “type”: “string”,
            “name”: “vCenterServer,
            “scope”: “local”,
            “value”: {
                “string”: {
                    “value”: “$vcenter”
                }
            }
        },
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

$vroUrl = "https://$($SECRETS_CONFIG.VRO_SERVER):443/vco/api/workflows/$($SECRETS_CONFIG.VRO_WORKFLOW_ID)/executions"

if($env:function_debug -eq "true") {
    Write-Host "DEBUG: vRoVmID=$vroVmId"
    Write-Host "DEBUG: vRoURL=`"$($vroUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: body=$vroBody"
}

Write-Host "Applying vSphere Tag: $($SECRETS_CONFIG.TAG_NAME) to VM: $vm ..."
if($env:skip_vro_cert_check -eq "true") {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Body $vroBody -Headers $headers -SkipHeaderValidation -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Body $vroBody -Headers $headers -SkipHeaderValidation 
}