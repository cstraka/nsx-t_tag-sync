Set-PowerCLIConfiguration -InvalidCertificateAction Ignore  -DisplayDeprecationWarnings $false -ParticipateInCeip $false -Confirm:$false | Out-Null

# Process function Secrets passed in

#production inputs
$SECRETS_FILE = "/var/openfaas/secrets/nsx-secrets"
$json = $args | ConvertFrom-Json

# Process payload sent from vCenter Server Event
Write-Host "DEBUG: json=`"$($json | Format-List | Out-String)`""

$vcenter = ($json.source -replace "https://","" -replace "/sdk","")
$vmMoRef = $json.data.vm.vm.value
$vm = $json.data.vm.name

if($env:prod_environment -ne "true") {
    Write-Host "DEBUG: json=`"$($vcenter)'"
    Write-Host "DEBUG: json=`"$($vmMoRef)'"
    Write-Host "DEBUG: json=`"$($vm)'"
}