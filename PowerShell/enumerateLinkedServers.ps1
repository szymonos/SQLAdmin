<#
.Synopsis
Skrypt odpytujący wersję SQL na wskazanych serwerach.
.Description
Informacje o wersjach SQL:
https://support.microsoft.com/en-us/help/321185/how-to-determine-the-version-edition-and-update-level-of-sql-server-an
.Example
Copy-Item '.\sql\SQLServerVersions.ps1' -Destination '\\abcdata\files\COMPANY\DT\Administratorzy\Git\PowerShell\SQL' -Force
& "SQL\enumerateLinkedServers.ps1"
& "SQL\enumerateLinkedServers.ps1" -OutTerminal 1
#>
param (
    [int]$RegCheck = 0,                 # Sprawdza informacje o serwerze SQL odpytując zdalnie rejestr
    [int]$OutTerminal = 0,              # Zwraca informacje na terminalu zamiast do pliku CSV
    [int]$CheckOtherNodes = 0,           # Zwraca informacje o serwerach SQL na nieaktywnych node'ach klastra
    [string]$OutDir = '.\CSV\Export'    # Ścieżka docelowa zapisywania wynikowego pliku
)

$ErrorActionPreference = 'SilentlyContinue'
# Get cluster nodes
$sqlServersCSV = '.\CSV\Import\SQLServers.csv'

if($false -eq (Test-Path $OutDir)) {New-Item $OutDir -ItemType Directory}
$outputCSV = Join-Path -Path $OutDir -ChildPath 'enumLinkedServers.csv'
$inactiveServersCSV = Join-Path -Path $OutDir -ChildPath 'SQLInactive.csv'

#[PSObject[]]$sqlServers = New-Object PSObject -Property @{SQLServer = 'BPDDB'; Env = 'Dev'; License = 'MSDN'; Desc = ''}
#$sqlServers += New-Object PSObject -Property @{SQLServer = 'ABCUFO'; Env = 'Prod'; License = 'Open'; Desc = ''}

$qrySrvInfo = "
select
    serverproperty('MachineName') as SQLServerName
    ,a.server_id as ServerId
    ,a.name as ServerName
    ,a.provider as Provider
    ,a.data_source as DataSource
    ,a.catalog as Catalog
    ,l.remote_name as RemoteLogin
from
    sys.servers as a
    left outer join sys.linked_logins as l
        on l.uses_self_credential = 0
        and l.server_id = a.server_id
where
    a.server_id <> 0"

function Invoke-SQL {
    param(
        [string] $ServerInstance,
        [string] $Database = 'master',
        [string] $Query
    )
    $connectionString = "Data Source=$ServerInstance; " +
                        "Integrated Security=SSPI; " +
                        "Initial Catalog=$Database;" +
                        "Connect Timeout=2"
    $connection = New-Object system.data.SqlClient.SQLConnection($connectionString)
    $command = New-Object system.data.sqlclient.sqlcommand($Query, $connection)
    $connection.Open()
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $connection.Close()
    $dataSet.Tables
}

$sqlServers = Import-Csv -Path $sqlServersCSV
$srvProperties = @()
$srvInactive = @()
foreach ($server in $sqlServers) {
    #$server = New-Object PSObject -Property @{SQLServer = 'abcufo'; Env = 'Prod'; License = 'Open'; Desc = ''}
    try {
        [PSObject[]]$srvProperty = Invoke-SQL -ServerInstance $server.SQLServer -Query $qrySrvInfo
        if('' -eq $srvProperty) {
            Write-Host "$($server.SQLServer) - no linked servers found" -ForegroundColor Cyan
        } else {
            $srvProperties += $srvProperty | Select-Object -Property @{Name = 'Env'; Expression = { $server.Env } }, SQLServerName, ServerId, ServerName, Provider, DataSource, Catalog, RemoteLogin
            Write-Host "$($server.SQLServer) - $($srvProperty.Count) linked servers found" -ForegroundColor Green
        }
    } catch {
        Write-Host "$($server.SQLServer) - cannot connect to server" -ForegroundColor Yellow
        $srvInactive += $server.SQLServer
    }
}

if($OutTerminal -ne 1)
{
    $srvInactive | Export-Csv -Encoding utf8 -NoTypeInformation $inactiveServersCSV
    $srvProperties | Export-Csv -Encoding utf8 -NoTypeInformation $outputCSV
    Write-Host "`nResults have been saved to file:" -ForegroundColor Yellow
    Resolve-Path $outputCSV | Convert-Path
} else {
    $srvProperties | Format-Table -AutoSize -Property Env, SQLServerName, ServerId, ServerName, Provider, DataSource, Catalog
}
