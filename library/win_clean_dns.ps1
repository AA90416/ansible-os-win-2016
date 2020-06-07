#!powershell

# POWERSHELL_COMMON
# WANT_JSON

function get-records($ipv4, $credential, $resultObj) {
    try{
        $dns_entries = Invoke-Command -ScriptBlock { Get-DnsServerResourceRecord -ZoneName "dci.local" | Where-Object {$_.RecordData.IPv4Address -contains "$Using:ipv4"}} -ComputerName na10dc01.dci.local -Credential $credential -Verbose
    }
    catch {
        Fail-Json $_.Exception.Message
    }
    return $dns_entries
}

########### Main script
$params = Parse-Args $args
$address = Get-AnsibleParam $params "address"
$svcUser = Get-AnsibleParam $params "username"
$svcPass = Get-AnsibleParam $params "password"

$script_result = New-Object psobject @{
    changed = $FALSE
}

$secpasswd = ConvertTo-SecureString $svcPass -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($svcUser, $secpasswd)

$records = get-records $address $creds $script_result
Set-Attr $script_result "msg" $records

foreach ($r in $records.HostName) {
    try {
	    Invoke-Command -ScriptBlock { Remove-DnsServerResourceRecord -ZoneName "DCI.local" -RRType "A" -Name "$Using:r" -Force } -ComputerName na10dc01.dci.local -Credential $creds -Verbose
    }
    catch {
        Fail-Json $_.Exception.Message
    }
    $script_result.changed = $TRUE
} 

Exit-Json $script_result
