#!powershell

# WANT_JSON
# POWERSHELL_COMMON

function check-group($creds, $server) {
    $groupName = $server + "Admins"
    $chkGrp = Get-ADGroup -Server DCI.local -Credential $creds -LDAPFilter "(SAMAccountName=$groupName)"
    if ($chkGrp -eq $null) { return 0 }
    else { return 1 }
}

function create-group($creds, $server, $resultObj) {
    $groupName = $server + "Admins"
    if ($(check-group $creds $server) -eq 0) { 
        try {
            New-ADGroup -server DCI.local -Credential $creds -Name $groupName -SamAccountName $groupName -GroupCategory Security -GroupScope Global -DisplayName "$server Administrators" -Path "OU=$os,OU=Groups,OU=USER,OU=DCI,DC=DCI,DC=local" -Description "Admin group - Programmatically generated"
        }
        catch {
            Fail-Json $_.Exception.Message
        }
        $resultObj.changed = $TRUE
    }
    else { return }
}

function delete-group($creds, $server, $resultObj) {
    $groupName = $server + "Admins"
    $chkGrp = Get-ADGroup -Server DCI.local -Credential $creds -LDAPFilter "(SAMAccountName=$groupName)"
    if ($chkGrp -ne "") {
        try {
            Remove-ADGroup -Server DCI.local -Credential $creds -Identity $groupName -Confirm:$false
        }
        catch {
            Fail-Json $_.Exception.Message
        }
        $resultObj.changed = $TRUE
    }
    else { return }
}

######## Main script logic
$params = Parse-Args $args
$password = Get-AnsibleParam $params "password"
$svcPrincipal = Get-AnsibleParam $params "svcPrincipal"
$serverName = Get-AnsibleParam $params "server"  
$os = Get-AnsibleParam $params "os"
$state = Get-AnsibleParam $params "state"

$script_result = New-Object psobject @{
    changed = $FALSE
}

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$ad_creds = New-Object System.Management.Automation.PSCredential ($svcPrincipal, $secpasswd)

switch ($state) {
    present { create-group $ad_creds $serverName $script_result }
    absent { delete-group $ad_creds $serverName $script_result }
    default { Fail-Json "No state or invalid state provided. Valid values are: present, absent" }
} 

Exit-Json $script_result
