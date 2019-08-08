<#
.Synopsis
Skrypt tworzący dacpac ze wszystkich baz na serwerach SQL określonych w $sqlServers.
.Description

.Example
& "SQL\enumerateDatabases.ps1"
#>

param (
    [string]$OutDir = '.\CSV\Export'    # Ścieżka docelowa zapisywania wynikowego pliku
)

$ErrorActionPreference = 'SilentlyContinue'
# Get cluster nodes
$sqlServers = Import-Csv -Path '.\CSV\Import\SQLServers.csv'
$outputCSV = Join-Path -Path $OutDir -ChildPath 'enumDatabases.csv'
$inactiveServersCSV = Join-Path -Path $OutDir -ChildPath 'SQLInactive.csv'
if($false -eq (Test-Path $OutDir)) {New-Item $OutDir -ItemType Directory}

try {
    $credadm = Import-CliXml -Path "$($env:USERPROFILE)\adm.cred"
} catch {
    $credadm = Get-Credential
}
#$sqlServers = 'ABCUFO', 'ABCUFODEV1', 'ABCUFOSTAGE', 'UFO3X', 'ABCREP2\REP'

$dbsQuery = "
select
    d.database_id
   ,d.name as DBName
   ,d.recovery_model_desc as RecoveryModel
   ,sum(f.size) * 8.0 / 1024 as MDFSizeMB
   ,l.LDFSizeMB
   ,serverproperty('ServerName') as SQLServerName
   ,serverproperty('ComputerNamePhysicalNetBIOS') as ComputerName
from
    sys.master_files as f
    inner join sys.databases as d
        on d.database_id > 4
		and d.database_id = f.database_id
    inner join
        (select
             f.database_id
            ,f.size * 8.0 / 1024 as LDFSizeMB
         from
             sys.master_files as f
         where
             f.type = 1) as l
        on l.database_id = f.database_id
where
    f.type <> 1
group by
    d.database_id
   ,d.name
   ,d.recovery_model_desc
   ,l.LDFSizeMB"

$nameHostPhysicalScript = {
    $vmParam = Get-Item 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -ErrorAction 'SilentlyContinue'
    if ($null -eq $vmParam) {
        New-Object PSObject -Property @{VMHostName = $null}
    } else {
        $vmHostName = $vmParam.GetValue('PhysicalHostName')
        New-Object PSObject -Property @{VMHostName = $vmHostName}
    }
}

function Invoke-SQL {
    param(
        [string] $ServerInstance,
        [string] $Database = 'master',
        [string] $Query
    )
    $connectionString = "Data Source=$ServerInstance; " +
                        "Integrated Security=SSPI; " +
                        "Initial Catalog=$Database"
    $connection = New-Object system.data.SqlClient.SQLConnection($connectionString)
    $command = New-Object system.data.sqlclient.sqlcommand($Query,$connection)
    $connection.Open()
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $connection.Close()
    $dataSet.Tables
}

$dbsList = @()
$srvError = @()
foreach($server in $sqlServers){
#    $server = New-Object PSObject -Property @{'SQLServer' = 'ufo3x'; 'Env' = 'Prod'; 'License' = 'MPN'; 'Desc' = ''}
    try {
        $dbs = Invoke-SQL -ServerInstance $server.SQLServer -Query $dbsQuery -ErrorAction Stop
        $compName = ($dbs | Select-Object -First 1).ComputerName
        try {
            $vmHost = Invoke-Command -ComputerName $compName -Credential $credadm -ScriptBlock $nameHostPhysicalScript -ErrorAction Stop
        } catch {
            $vmHost = New-Object PSObject -Property @{VMHostName = '_#VMHostGetError'; PSComputerName = $compName; RunspaceId = $null}
        }
        $dbsList += $dbs | Select-Object -Property @{Name = 'Env';Expression = {$server.Env}}, @{Name = 'VMHost';Expression = {$vmHost.VMHostName}}, ComputerName, SQLServerName, DBName, RecoveryModel, MDFSizeMB, LDFSizeMB
        Write-Host "Enumerated server $($server.SQLServer)" -ForegroundColor Magenta
    } catch {
        Write-Host "Error connecting to server $($server.SQLServer)" -ForegroundColor Yellow
        $srvError += $server
    }
}

$dbsList | Export-Csv -Encoding utf8 -NoTypeInformation $outputCSV
$srvError | Export-Csv -Encoding utf8 -NoTypeInformation $inactiveServersCSV
Write-Host "`nResults have been saved to file:" -ForegroundColor Yellow
Resolve-Path $outputCSV | Convert-Path
