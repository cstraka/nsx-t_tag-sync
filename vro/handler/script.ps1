
# Process function Secrets passed in
$SECRETS_FILE = "/var/openfaas/secrets/vro-secrets"
$SECRETS_CONFIG = (Get-Content -Raw -Path $SECRETS_FILE | ConvertFrom-Json)

# Process payload sent from vCenter Server Event
$json = $args | ConvertFrom-Json
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""
}

# Set vCneter server name to a variable from event message text
$vcenter = ($json.source -replace "https://","" -replace "/sdk","");
$keyNumber = $json.$keyNumber

# Pull VM name from event message text and set it to variable
$separator = "object"," "
$option = [System.StringSplitOptions]::RemoveEmptyEntries
$FullFormattedMessage = $json.data.FullFormattedMessage.split($separator,$option)
$FullFormattedMessage = $FullFormattedMessage.split([Environment]::NewLine)
$vm = $FullFormattedMessage[$FullFormattedMessage.count-1]

# Test for existince of content in $vm variable and exit script early if test results false
if($vmMoRef -eq "" -or $vm -eq "") {
    Write-Host "Unable to retrieve VM Object from Event payload, please ensure Event contains VM result"
    exit
}

# This syntax is very specific.  
# The 'name' element (e.g. "name": "virtualMachineName" & "name": "vcenterName") MUST be a named input to the VRO workflow with a matching type (e.g. 'string')
# CASE SENSITIVE.
$vroBody = @"
{
    "parameters": [
        {
            "type": "string",
            "name": "virtualMachineName",
            "scope": "local",
            "value": {
                "string": {
                    "value": "$vm"
                }
            }
        },
        {
            "type": "int32",
            "name": "keyNumber",
            "scope": "local",
            "value": {
                "number": {
                    "value": $keyNumber
                }
            }
        },
        {
            "type": "string",
            "name": "vcenterName",
            "scope": "local",
            "value": {
                "string": {
                    "value": "$vcenter"
                }
            }
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

#Setting VRO URL
$vroUrl = "https://$($SECRETS_CONFIG.VRO_SERVER):443/vco/api/workflows/$($SECRETS_CONFIG.VRO_WORKFLOW_ID)/executions"

#writing variables to console if 'function_debug' is 'true' in stack.yml
if($env:function_debug -eq "true") {
    Write-Host "DEBUG: vRoVmID=$vroVmId"
    Write-Host "DEBUG: vRoURL=`"$($vroUrl | Format-List | Out-String)`""
    Write-Host "DEBUG: headers=`"$($headers | Format-List | Out-String)`""
    Write-Host "DEBUG: body=$vroBody"
}

#calling VRO
if($env:skip_vro_cert_check -eq "true") {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Body $vroBody -Headers $headers -SkipHeaderValidation -SkipCertificateCheck
} else {
    Invoke-Webrequest -Uri $vroUrl -Method POST -Body $vroBody -Headers $headers -SkipHeaderValidation 
}