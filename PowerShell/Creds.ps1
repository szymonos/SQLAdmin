<#
.Description
Import Credentials
$credsadm = Import-CliXml -Path "$($env:USERPROFILE)\adm.cred"
#>

<#
.Description
Save credentials to file
.Example
$Credential = Get-Credential
$Credential | Export-CliXml -Path "$($env:USERPROFILE)\adm.cred"
#>

<#
.Description
Change password and update credential
.Example
$login2Change = 'login_name'
$oldPass = (Read-Host -Prompt "Provide old password" -AsSecureString)
$newPass = (Read-Host -Prompt "Provide new password" -AsSecureString)
Set-ADAccountPassword -Credential $credsadm -Identity $login2Change -OldPassword $oldPass -NewPassword $newPass
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$env:USERDOMAIN\$login2Change", $newPass
$Credential | Export-CliXml -Path "$($env:USERPROFILE)\adm.cred"
#>
