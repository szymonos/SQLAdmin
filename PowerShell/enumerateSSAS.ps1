<#
.Description
Skrypt inwentaryzujący wszystkie bazy danych, kostki i wymiary na serwerach SSAS
.Example
& "PowerShell\enumerateSSAS.ps1"
#>

param(
    [string]$OutDir = '.\CSV\Export'
)

[Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices")

if($false -eq (Test-Path $OutDir)) {New-Item $OutDir -ItemType Directory}
$outputDBsCSV = Join-Path -Path $OutDir -ChildPath 'enumOlapDatabases.csv'
$outputDimsCSV = Join-Path -Path $OutDir -ChildPath 'enumOlapDimensions.csv'

$olapServers = Import-Csv '.\CSV\Import\OLAPServers.csv'

$qryDatabases = 'select [CATALOG_NAME] from $system.dbschema_catalogs'
$qryDims = 'select [CATALOG_NAME],[CUBE_NAME],[DIMENSION_CAPTION] from $system.MDSchema_Dimensions where [CUBE_NAME]='

[psobject[]]$dimRows = @()
[psobject[]]$dbRows = @()

Write-Output 'Enumerating databases on:'
foreach($olapSrv in $olapServers) {
    $srvName = $olapSrv.ServerName
    [xml]$dbsXML = Invoke-ASCmd -Server:$srvName -Query:$qryDatabases
    $dbs = $dbsXML.return.root.row.CATALOG_NAME
    $server = New-Object Microsoft.AnalysisServices.Server
    $server.connect($srvName)
    Write-Output $srvName
    foreach($dbName in $dbs){
        $db = $server.Databases.FindByName($dbName)
        $dbProps = [ordered]@{
            Env = $olapSrv.Environment;
            ServerName = $srvName;
            DBName = $db.Name;
            DBSize = [math]::round($db.EstimatedSize / 1MB, 2);
            DBLastUpdate = $db.LastUpdate
            DBState = $db.State
            DbId = $srvName, $db.Name -join '.'
        }
        $dbRows += New-Object -TypeName PSObject -Property $dbProps
        $cubes = $db.Cubes.Name
        foreach ($cubeName in $cubes){
            $qryDimCube = $qryDims + "'$cubeName'"
            [xml]$dimsXML = Invoke-ASCmd -Server:$srvName -Database:$dbName -Query:$qryDimCube
            $dims = $dimsXML.return.root.row.DIMENSION_CAPTION
            foreach($dimension in $dims) {
                $dimProps = [ordered]@{
                    Env = $olapSrv.Environment;
                    ServerName = $srvName;
                    DBName = $db.Name;
                    CubeName = $cubeName
                    DimensionName = $dimension
                    DbId = $srvName, $db.Name -join '.'
                }
                $dimRows += New-Object -TypeName psobject -Property $dimProps
            }
        }
    }
    $server = $null
}

$dbRows | Export-Csv -Encoding utf8 -NoTypeInformation $outputDBsCSV
Write-Host "`nOLAP Databases have been saved to file:" -ForegroundColor Yellow
Resolve-Path $outputDBsCSV | Convert-Path

$dimRows | Export-Csv -Encoding utf8 -NoTypeInformation $outputDimsCSV
Write-Host "`nOLAP cubes and dimensions have been saved to file:" -ForegroundColor Yellow
Resolve-Path $outputDimsCSV | Convert-Path
#$dims | Format-Table -AutoSize *
