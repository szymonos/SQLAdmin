<#
.Synopsis
Find newest backup file of each db subfolder
.Example
& "PowerShell\LatestFilesInFolders.ps1" -SourcePath "\\ServerName\DB_Backups"
& "PowerShell\LatestFilesInFolders.ps1" -SourcePath "\\ServerName\DB_Backups" -BackupDate "20190807"
& "PowerShell\LatestFilesInFolders.ps1" -SourcePath "\\ServerName\DB_Backups" -BackupDate "20190807" -ExportCSV 1
#>
param (
    [bool]$ExportCSV = $false,
    [string]$SourcePath,
    [string]$BackupDate
)

$excluded = 'master', 'model', 'msdb'
$csvExportDir = 'C:\Inst\Scripts\CSV\Export'

#Grab a recursive list of all subfolders
$subFolders = Get-ChildItem -Path $SourcePath -Directory | Where-Object { $_.Name -notin $excluded } | ForEach-Object -Process { $_.FullName }
#Get-ChildItem -Path $Path -Directory | ForEach-Object -Process {$_.Name}

#Iterate through the list of subfolders and grab the first file in each
$fullBackups = foreach ($folder in $subFolders) {
    if ([string]::IsNullOrEmpty($backupDate)) {
        Get-ChildItem -Path $folder -Filter '*FULL*.bak' -File |
        Sort-Object { $_.CreationTime } |
        Select-Object -Last 1
    }
    else {
        Get-ChildItem -Path $folder -Filter '*FULL*.bak' -File |
        Where-Object { $_.CreationTime.ToString('yyyyMMdd') -eq $backupDate }
    }
}

$dbsFiles = foreach ($fullBackup in $fullBackups) {
    #    $fullBackup = $fullBackups[3]
    $prop = [ordered]@{
        DBName   = (Split-Path -Path $fullBackup.DirectoryName -Leaf);
        FileName = $fullBackup.FullName
    }
    New-Object PSObject -Property $prop
}
if ($ExportCSV) {
    if (!(Test-Path $csvExportDir)) { New-Item -ItemType Directory $csvExportDir }
    $dbsFiles | Export-Csv -Path (Join-Path -Path $csvExportDir -ChildPath 'enumProdBackups.csv') -NoTypeInformation -Encoding utf8
}
else {
    $dbsFiles | ForEach-Object { Write-Output ($_.DBName + ',' + $_.FileName) }
}
