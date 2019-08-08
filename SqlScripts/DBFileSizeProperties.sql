/* Change file size */
/*
use master;
go
alter database dbname
modify file (name = dbname_Log,size = 10240,filegrowth = 10240);
go
*/
/*
use dbname
go
dbcc shrinkfile(N'dbname_Data', 600000)
go
*/
declare @dbfiles as table (
    ServerName sql_variant not null
   ,DBName sysname
   ,FileName sysname
   ,DBSizeMB decimal(15, 2) not null
   ,DBUsedSpaceMB decimal(15, 2) not null
   ,DBFreeSpaceMB decimal(15, 2) not null
   ,DBPctFree decimal(5, 2) not null
   ,DBGrowth nvarchar(20) not null
   ,LogName sysname
   ,LogSizeMB decimal(15, 2) not null
   ,LogFreeSpaceMB decimal(15, 2) not null
   ,LogPctFree decimal(5, 2) not null
   ,LogGrowth nvarchar(20) not null
   ,DBState nvarchar(20) not null
)

declare @sqlcmd nvarchar(max)
    = N'use ?
select
    ServerName = serverproperty(''MachineName'')
   ,DBName = ''?''
   ,DBFileName = f.name
   ,DBSizeMB = cast(f.size / 128.0 as decimal(15, 2))
   ,DBUsedSpaceMB = cast(cast(fileproperty(f.name, ''SpaceUsed'') as int) / 128.0 as decimal(15, 2))
   ,DBFreeSpaceMB = cast(f.size / 128.0 - cast(fileproperty(f.name, ''SpaceUsed'') as int) / 128.0 as decimal(15, 2))
   ,DBPctFree = 1 - cast(cast(fileproperty(f.name, ''SpaceUsed'') as decimal(15, 0)) / f.size as decimal(5, 2))
   ,DBGrowth = case f.is_percent_growth
             when 0 then format(cast(f.growth / 128.0 as int), ''G'') + ''MB''
             when 1 then format(f.growth, ''G'') + ''%''
             else null end
   ,LogName = l.name
   ,LogSizeMB = cast(l.size / 128.0 as decimal(15, 2))
   ,LogFreeSpaceMB = cast(l.size / 128.0 - cast(fileproperty(l.name, ''SpaceUsed'') as int) / 128.0 as decimal(15, 2))
   ,LogPctFree = 1 - cast(cast(fileproperty(l.name, ''SpaceUsed'') as decimal(15, 0)) / l.size as decimal(5, 2))
   ,LogGrowth = case l.is_percent_growth
             when 0 then format(cast(l.growth / 128.0 as int), ''G'') + ''MB''
             when 1 then format(l.growth, ''G'') + ''%''
             else null end
   ,DBState = f.state_desc
from
    sys.database_files as f
    inner join sys.database_files as l
        on l.type = 1
where
    f.type = 0'

insert into @dbfiles exec sys.sp_MSforeachdb @sqlcmd

select
    d.ServerName
   ,d.DBName
   ,d.FileName
   ,d.DBSizeMB
   ,d.DBUsedSpaceMB
   ,d.DBFreeSpaceMB
   ,d.DBPctFree
   ,d.DBGrowth
   ,d.LogName
   ,d.LogSizeMB
   ,d.LogFreeSpaceMB
   ,d.LogPctFree
   ,d.LogGrowth
   ,d.DBState
from
    @dbfiles as d
order by
    d.DBFreeSpaceMB desc
	--d.LogFreeSpaceMB desc
    --d.DBName
    --d.DBPctFree
    --d.DBSizeMB desc
	--d.DBGrowth