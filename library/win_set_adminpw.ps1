#!powershell

# WANT_JSON
# POWERSHELL_COMMON

function Get-AdminAcct {
    $result = New-Object psobject @{
		machine = ""
        adminAcct = ""
        adminSid = ""
    }

    $computerName = $env:COMPUTERNAME
    $computer = [ADSI] "WinNT://$computerName,Computer"
    foreach ( $childObject in $computer.Children ) {
        # Skip objects that are not users.
        if ( $childObject.Class -ne "User" ) {
            continue
        }
        $type = "System.Security.Principal.SecurityIdentifier"
        
        $childObjectSID = new-object $type($childObject.objectSid[0],0)
        
        if ( $childObjectSID.Value.EndsWith("-500") ) {
			$result.machine = $computerName
            $result.adminAcct = $($childObject.Name[0])
            $result.adminSid = $($childObjectSID.Value)
            break
        }
    }

    return $result
}

#### Main script logic
$params = Parse-Args $args
$password = Get-AnsibleParam $params "password"

$script_result = New-Object psobject @{
    changed=$FALSE
}

$admin = Get-AdminAcct
$user = [adsi]"WinNT://$($admin.machine)/$($admin.adminAcct),user"
$user.SetPassword($password)
$user.SetInfo()
$script_result.changed = $TRUE

Exit-Json $script_result
