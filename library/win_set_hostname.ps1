#!powershell

# WANT_JSON
# POWERSHELL_COMMON

######## Main script logic
$params = Parse-Args $args
$password = Get-AnsibleParam $params "password"
$svcPrincipal = Get-AnsibleParam $params "svcPrincipal"
$computer = Get-AnsibleParam $params "computer"

$script_result = New-Object psobject @{
    changed = $FALSE
}

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$dj_creds = New-Object System.Management.Automation.PSCredential ($svcPrincipal, $secpasswd)

if($computer -eq $env:COMPUTERNAME) { Exit-Json $script_result }
else {
    Rename-Computer -ComputerName $env:COMPUTERNAME -NewName $computer -LocalCredential $dj_creds
    $script_result.changed = $TRUE
}

Exit-Json $script_result
