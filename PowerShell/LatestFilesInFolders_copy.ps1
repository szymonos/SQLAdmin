<#
.Synopsis
Find newest file of each subfolder
.Description
http://sirsql.net/content/2011/07/07/201176grabbing-the-newest-file-from-subdirectories-using-powershel-html/
.Example
PowerShell\LatestFilesInFolders_copy.ps1
#>

$srvSqlList = Import-Csv -Path '.\CSV\Export\enumSQLServers.csv' | Where-Object {$_.Env -eq 'DEV'} | Select-Object -ExpandProperty MachineName

# Get credentials used for connecting to servers through WinRM
try {
    $credsadm = Import-CliXml -Path "$($env:USERPROFILE)\adm.cred"
} catch {
    $credsadm = Get-Credential -Message 'Credentials required to get information about SQL servers from registry'
}

$copyFile = '.\PowerShell\LatestFilesInFolders.ps1'
$destDir = 'C:\Inst\Scripts'
foreach ($destServer in $srvSqlList) {
    #$destServer = $srvSqlList[0]
    Write-Output "Copying file to server $destServer"
    try {
        $sessionTo = New-PSSession -ComputerName $destServer -Credential $credsadm
        Invoke-Command -Session $sessionTo -ErrorAction Stop -ScriptBlock {
            if($false -eq (Test-Path -Path $using:destDir)) {New-Item -ItemType Directory $using:destDir}
        }
        Copy-Item -Path $copyFile -Destination $destDir -ToSession $sessionTo -Force -ErrorAction Stop
        Write-Host 'Copy file succeded' -ForegroundColor Green
    } catch {
        Write-Host 'Copy file failed' -ForegroundColor Red
    }
    Remove-PSSession $sessionTo
}
