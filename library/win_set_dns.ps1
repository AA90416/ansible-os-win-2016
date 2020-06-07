#!powershell

# WANT_JSON
# POWERSHELL_COMMON
 
Set-StrictMode -Off
# Helper function to convert a powershell object to JSON to echo it, exiting
# the script
function Exit-Json($obj)
{
    echo $obj | ConvertTo-Json
    Exit
}
# Helper function to add the "msg" property and "failed" property, convert the
# powershell object to JSON and echo it, exiting the script
function Fail-Json($obj, $message)
{
    $obj | Add-Member -MemberType NoteProperty -Name msg -Value "$message"
    $obj | Add-Member -MemberType NoteProperty -Name failed -Value $TRUE
    echo $obj | ConvertTo-Json
    Exit
}

function Get-TargetAdapter {
# This function makes some DiData/DCI-based assumptions.
# 1) The image being deployed is the DiData standard Win2012R2 image.
# 2) The NICs are named "Ethernet", "Ethernet #2", "Ethernet #N"
    $nics = Get-NetAdapter
    $indices = @()
    if ($nics.count -ne 1) {
    # There's more than one NIC, find the one named "Ethernet"
        foreach($nic in $nics) {
            if($nic.Name -eq "Ethernet") {
                return $nic.ifIndex
            }
        }
        return 0
    }
    else {
    # There's only one adapter on the system, so give me that one.
        return $(Get-NetAdapter).ifIndex
    }
}

####### Main script logic
$params = Parse-Args $args
$dns1 = Get-AnsibleParam $params "dns1" 
$dns2 = Get-AnsibleParam $params "dns2"

$script_result = New-Object psobject @{
    changed = $FALSE
}
if(!$dns1 -and !$dns2) { 
    Fail-Json $script_result "Incorrect number of DNS servers specified-- $params"
}
if($dns1 -and $dns2) { $new_dns = @($dns1,$dns2) }
else { $new_dns = $($dns1) }

$target = Get-TargetAdapter

if($target -eq 0) {
    Fail-Json $script_result "Unable to identify system primary NIC."
}
else {
    $current_dns = $(Get-DnsClientServerAddress -InterfaceIndex $target).ServerAddresses
    if(@(Compare-Object $current_dns $new_dns -SyncWindow 0).Length -ne 0) {
        Set-DnsClientServerAddress -InterfaceIndex $target -ServerAddresses $new_dns
        $script_result.changed = $TRUE
    }
    
    Exit-Json $script_result
}
