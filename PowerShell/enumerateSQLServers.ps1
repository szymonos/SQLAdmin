<#
.Synopsis
Skrypt odpytujący wersję SQL na wskazanych serwerach.
.Description
Informacje o wersjach SQL:
https://support.microsoft.com/en-us/help/321185/how-to-determine-the-version-edition-and-update-level-of-sql-server-an
.Example
& "PowerShell\enumerateSQLServers.ps1"
& "PowerShell\enumerateSQLServers.ps1" -RegCheck 0 -OutTerminal 1
& "PowerShell\enumerateSQLServers.ps1" -RegCheck 1 -OutTerminal 1
& "PowerShell\enumerateSQLServers.ps1" -RegCheck 1 -OutTerminal 0 -CheckOtherNodes 1
& "PowerShell\enumerateSQLServers.ps1" -RegCheck 0 -OutTerminal 1 -CheckOtherNodes 1
& "PowerShell\enumerateSQLServers.ps1" -RegCheck 1 -OutTerminal 1 -CheckOtherNodes 1
#>
param (
    [bool]$RegCheck = 1,                # checking SQL properties through registry on servers without SQL access
    [bool]$OutTerminal = 0,             # returns information on terminal instead writing it to disk
    [bool]$CheckOtherNodes = 1,         # check inactive nodes on clustered servers
    [bool]$includeImportedProps = 1,    # include SQL server properties from additional CSV file
    [string]$OutDir = '.\CSV\Export'
)
# Import files
$sqlServersCSV = '.\CSV\Import\SQLServers.csv'
$propsOtherCSV = '.\CSV\Import\SQLSrvPropsOther.csv'

# Export files
if($false -eq (Test-Path $OutDir)) {New-Item $OutDir -ItemType Directory}
$outputCSVActive = Join-Path -Path $OutDir -ChildPath 'enumSQLServers.csv'
$outputCSVInactive = Join-Path -Path $OutDir -ChildPath 'enumSQLSrvIncactive.csv'

# Get credentials used for connecting to servers through WinRM
if ($RegCheck -eq 1 -or $CheckOtherNodes -eq 1) {
    try {
        $credsadm = Import-CliXml -Path "$($env:USERPROFILE)\adm.cred"
    } catch {
        $credsadm = Get-Credential -Message 'Credentials required to get information about SQL servers from registry'
    }
}

<# SQL Query returnning SQL server properties #>
$qrySrvInfo = "/* Check SQL Server Version, Edition and Hostname */
    select top 1
        serverproperty('MachineName') as SQLServerName
       ,isnull(serverproperty('InstanceName'), 'MSSQLSERVER') as InstanceName
       ,serverproperty('ComputerNamePhysicalNetBIOS') as MachineName
       ,case
               when charindex('-', @@VERSION) < charindex('(', @@VERSION) then left(@@version, charindex('-', @@version) - 2)
               else left(@@version, charindex('(', @@version) - 2)end as ServerVersion
       ,serverproperty('ProductLevel') as ProductLevel
       ,serverproperty('ProductUpdateLevel') as UpdateLevel
       ,serverproperty('ProductUpdateReference') as KB
       ,serverproperty('ProductVersion') as ProductVersion
       ,c.local_net_address as LocalAddress
       ,c.local_tcp_port as LocalPort
       ,serverproperty('Edition') as ServerEdition
       ,serverproperty('IsClustered') as IsClustered
       ,substring(@@version, charindex(') on', @@version) + 5, 255) as SystemVersion
       ,i.cpu_count as Cores
    from
        sys.dm_exec_connections as c
        cross join sys.dm_os_sys_info as i
    where
        c.local_tcp_port is not null"

<# Function building query string to get SQL Server and product version name #>
function Resolve-SQLSrvVerQuery {
    param (
        [string]$verMajor,
        [string]$verMinor
    )
    Write-Output "/* Check SQL Server Version SP and CU */
select top 1
    'Microsoft ' + v.MajorVersionName as ServerVersion
   ,iif(charindex(' ', v.Branch) > 0, left(v.Branch, charindex(' ', v.Branch) - 1), v.Branch) as ProductLevel
   ,stuff(v.Branch, 1, charindex(' ', v.Branch), '') as UpdateLevel
from
    dbo.SQLServerVersions as v
where
    v.MajorVersionNumber = $verMajor
    and v.MinorVersionNumber <= $verMinor
order by
    v.MinorVersionNumber desc"
}

<# function used for connecting to SQL server #>
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
    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($Query, $connection)
    $connection.Open()
    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $connection.Close()
    $dataSet.Tables
}

<# Get information about SQL instances through registry #>
function Get-SqlRegProperties {
    param(
        [string] $SrvName,
        [string] $InstName
    )
    $sqlServersReg = Invoke-Command -ComputerName $SrvName -Credential $credsadm -ErrorAction Stop -ScriptBlock {
        $numCores = try {
            (Get-CIMInstance -Class 'Win32_Processor' | Measure-Object -Property NumberOfCores -Sum).Sum
        } catch {
            (Get-WmiObject -Class 'win32_processor' | Measure-Object -Property NumberOfCores -Sum).Sum
        }
        $MachineName = $env:COMPUTERNAME
        $sqlInstances = Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction 'SilentlyContinue'
        if ($using:InstName -eq '') {
            $instanceNames = $sqlInstances.Property
        } else {
            $instanceNames = $using:InstName
        }
        foreach ($instance in $instanceNames) {
            $instanceValue = $sqlInstances.GetValue("$instance")
            $Cluster = Get-Item "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanceValue)\Cluster" -ErrorAction 'SilentlyContinue'
            if ($null -ne $Cluster) {
                    $SQLServerName =  $Cluster.GetValue('ClusterName')
                    $isClustered = 1
            } else {
                    $SQLServerName = $MachineName
                    $isClustered = 0
            }
            $sqlSetup = Get-Item "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instanceValue)\Setup" -ErrorAction 'SilentlyContinue'
            $sqlSetup | Select-Object @{Name = 'SQLServerName'; Expression = {$SQLServerName}},
                @{Name = 'InstanceName'; Expression = {$instance}},
                @{Name = 'MachineName'; Expression = {$MachineName}},
                @{Name = 'IsClustered'; Expression = {$isClustered}},
                @{Name = 'Cores'; Expression = {$numCores}},
                @{Name = 'ProductVersion'; Expression = {$sqlSetup.GetValue('PatchLevel')}},
                @{Name = 'ServerEdition'; Expression = {$sqlSetup.GetValue('Edition')}}
        }
    }
    foreach ($sqlSrvReg in $sqlServersReg) {
        $verMajor = $sqlSrvReg.ProductVersion.substring(0,2)
        $verMinor = $sqlSrvReg.ProductVersion.substring(5,4)
        $srvVerLevel = Invoke-SQL -ServerInstance 'ABCSQLMON' -Database 'Admin' -Query (Resolve-SQLSrvVerQuery -verMajor $verMajor -verMinor $verMinor)
        $ipAddress = Resolve-DnsName $sqlSrvReg.SQLServerName | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue
        $sqlSrvReg | Select-Object -Property SQLServerName,
            InstanceName,
            MachineName,
            Cores,
            @{Name = 'ServerVersion'; Expression = {$srvVerLevel.ServerVersion}},
            @{Name = 'ProductLevel'; Expression = {$srvVerLevel.ProductLevel}},
            @{Name = 'UpdateLevel'; Expression = {$srvVerLevel.UpdateLevel}},
            KB,
            ProductVersion,
            ServerEdition,
            @{Name = 'LocalAddress'; Expression = {$ipAddress}},
            LocalPort,
            IsClustered
    }
}

<# Main loop iterating through imported servers list and getting it's properties #>
$sqlServers = Import-Csv -Path $sqlServersCSV
[psobject[]]$srvProperties = @()
[psobject[]]$srvInactive = @()
Write-Host "`nChecking servers properties" -ForegroundColor Yellow
foreach ($server in $sqlServers) {
    Write-Host 'Checking Server'$server.SQLServer.ToUpper()
    $srvGetOK = $true
    try {
        $srvQueryProps = Invoke-SQL -ServerInstance $server.SQLServer -Query $qrySrvInfo -ErrorAction Stop
        Write-Host 'Success' -ForegroundColor Cyan
    } catch {
        if ($RegCheck -eq 1) {
            try {
                $srvQueryProps = Get-SqlRegProperties -SrvName $server.SQLServer -ErrorAction Stop
                Write-Host 'Server'$server.SQLServer.ToUpper()'- checked through registry' -ForegroundColor Cyan
            } catch {
                $srvInactive += New-Object PSObject -Property @{SrvName = $server.SQLServer}
                $srvGetOK = $false
                Write-Host 'Server'$server.SQLServer.ToUpper()'- is not accessible' -ForegroundColor 'Magenta'
            }
        } else {
            $srvInactive += New-Object PSObject -Property @{SrvName = $server.SQLServer}
            $srvGetOK = $false
            Write-Host 'Server'$server.SQLServer.ToUpper()'- is not accessible' -ForegroundColor 'Red'
        }
    }
    if($srvGetOK) {
        foreach($srvProperty in $srvQueryProps) {
            $srvProp = [ordered]@{
                Env           = $server.Env;
                SQLServerName = $srvProperty.SQLServerName;
                InstanceName  = $srvProperty.InstanceName;
                MachineName   = $srvProperty.MachineName;
                Cores         = $srvProperty.Cores;
                License       = $server.License;
                ServerVersion = $srvProperty.ServerVersion;
                ProductLevel  = $srvProperty.ProductLevel;
                UpdateLevel   = $srvProperty.UpdateLevel;
                KB            = $srvProperty.KB;
                ProductVersion= $srvProperty.ProductVersion;
                ServerEdition = $srvProperty.ServerEdition;
                LocalAddress  = $srvProperty.LocalAddress;
                LocalPort     = $srvProperty.LocalPort;
                IsClustered   = $srvProperty.IsClustered;
                Description   = $server.Desc;
                SystemVersion = $srvProperty.SystemVersion;
            }
            $srvProperties += New-Object -TypeName psobject -Property $srvProp
        }
    }
}

<# Check inactive nodes on clustered instances #>
if ($CheckOtherNodes -eq 1) {
    $clusterNodes = $srvProperties | Where-Object {$_.IsClustered -eq 1} | Select-Object Env, MachineName, InstanceName, License
    foreach ($instance in $clusterNodes) {
        $otherNode = Invoke-Command -ComputerName $instance.MachineName -Credential $credsadm -ScriptBlock {
            Get-ClusterNode | Where-Object {$_.NodeName -ne $using:instance.MachineName} | Select-Object NodeName
        }
        Write-Host $instance.MachineName.ToUpper()'\'$instance.InstanceName.ToUpper()'- checked inactive node' -ForegroundColor Green
        $srvProperty = Get-SqlRegProperties -SrvName $otherNode.NodeName -InstName $instance.InstanceName
        $srvProp = [ordered]@{
            Env           = $instance.Env;
            SQLServerName = $srvProperty.SQLServerName;
            InstanceName  = $srvProperty.InstanceName;
            MachineName   = $srvProperty.MachineName;
            Cores         = $srvProperty.Cores;
            License       = $instance.License;
            ServerVersion = $srvProperty.ServerVersion;
            ProductLevel  = $srvProperty.ProductLevel;
            UpdateLevel   = $srvProperty.UpdateLevel;
            KB            = $srvProperty.KB;
            ProductVersion= $srvProperty.ProductVersion;
            ServerEdition = $srvProperty.ServerEdition;
            LocalAddress  = $srvProperty.LocalAddress;
            LocalPort     = $srvProperty.LocalPort;
            IsClustered   = 2;
            Description   = $null;
            SystemVersion = $srvProperty.SystemVersion
        }
        $srvProperties += New-Object -TypeName psobject -Property $srvProp
    }
}

<# Import server properties from unaccessible servers #>
if($includeImportedProps){
    $SQLSrvPropsOther = Import-Csv -Path $propsOtherCSV
    $srvProperties += $SQLSrvPropsOther
    Write-Host 'Added imported properties from' (Split-Path $propsOtherCSV -Leaf) -ForegroundColor Magenta
}

<# Save or show the results depending on input parameter #>
if($OutTerminal -ne 1)
{
    $srvProperties | Export-Csv -Encoding utf8 -NoTypeInformation $outputCSVActive
    Write-Host "`nResults have been saved to file:" -ForegroundColor Yellow
    Resolve-Path $outputCSVActive | Convert-Path
    $srvInactive | Export-Csv -Encoding utf8 -NoTypeInformation $outputCSVInactive
} else {
    $srvProperties | Format-Table -AutoSize -Property Env, SQLServerName, InstanceName, MachineName, Cores, License, ServerVersion, ProductLevel, ProductVersion, ServerEdition, IsClustered
}
