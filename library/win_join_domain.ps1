#!powershell

# WANT_JSON
# POWERSHELL_COMMON

######## Main script logic
$params = Parse-Args $args
$domain = Get-AnsibleParam $params "domain"
$password = Get-AnsibleParam $params "password"
$svcPrincipal = Get-AnsibleParam $params "svcPrincipal"

$script_result = New-Object psobject @{
    changed = $FALSE
}
if(!(gwmi win32_computersystem).partofdomain) {
    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
    $dj_creds = New-Object System.Management.Automation.PSCredential ($svcPrincipal, $secpasswd)

    if($domain -eq $env:userdnsdomain) { Exit-Json $script_result }
    else {
	try {
            Add-Computer -DomainName $domain -Credential $dj_creds
            $script_result.changed = $TRUE
        }
        catch {
            Fail-Json $script_result
        }
    }
}

Exit-Json $script_result
