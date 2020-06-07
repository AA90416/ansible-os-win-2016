#!powershell
# Author: Wes Carlton
# Date: 1/19/2016
# This script is intended for consumption and use by Ansible Tower.

# WANT_JSON
# POWERSHELL_COMMON

function check-profile($profileName) {
	$out = $(Get-NetFirewallProfile -Name $profileName).Enabled
	if($out -eq "False") { return 0 }
	elseif($out -eq "True") { return 1 }
	return
}

function disable-profile($profileName) {
	Set-NetFirewallProfile -Name $profileName -Enabled False
}

####### Main script logic
$debug = 0
$script_result = New-Object psobject @{
    changed = $FALSE
}

$profiles = @('Domain','Public','Private')

foreach ($profile in $profiles) {
	$check = check-profile($profile)
	if($check -eq 1) {
		if($debug) { Write-Host "Firewall profile $profile found enabled. Disabling." }
		disable-profile($profile)
		$script_result.changed = $TRUE
	}
	elseif($debug -eq 1) { Write-Host "Firewall profile $profile is already disabled."}
}

Exit-Json $script_result

