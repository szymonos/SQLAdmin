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
    ServerName sysname not null
   ,DbId int not null
   ,DBName sysname not null
   ,DBFileName sysname not null
   ,TypeId int not null
   ,FileType nvarchar(60) not null
   ,DBSizeMB decimal(15, 1) not null
   ,DBUsedSpaceMB decimal(15, 1) null
   ,DBFreeSpaceMB decimal(15, 1) null
   ,DBPctFree decimal(5, 2) null
   ,GrU nvarchar(2) not null
   ,DBGrowth int not null
   ,DBState nvarchar(20) not null
   ,RecoverModel nvarchar(20) not null
   ,PhysicalName sysname not null
);

declare @sqlcmd nvarchar(max) = N'';

select
    @sqlcmd += N'use ' + d.name
               + N'
select
    ServerName = cast(serverproperty(''MachineName'') as sysname)
   ,DbId = db_id()
   ,DBName = db_name()
   ,DBFileName = f.name
   ,TypeId = f.type
   ,FileType = f.type_desc
   ,DBSizeMB = cast(f.size / 128.0 as decimal(15, 1))
   ,DBUsedSpaceMB = cast(cast(fileproperty(f.name, ''SpaceUsed'') as int) / 128.0 as decimal(15, 1))
   ,DBFreeSpaceMB = cast(f.size / 128.0 - cast(fileproperty(f.name, ''SpaceUsed'') as int) / 128.0 as decimal(15, 1))
   ,DBPctFree = 1 - cast(cast(fileproperty(f.name, ''SpaceUsed'') as decimal(15, 0)) / f.size as decimal(5, 2))
   ,GrU = case f.is_percent_growth
             when 0 then ''MB''
             when 1 then ''%''
             else null end
   ,DBGrowth = case f.is_percent_growth
             when 0 then cast(f.growth / 128.0 as int)
             when 1 then f.growth
             else null end
   ,DBState = f.state_desc
   ,RecoverModel = db.recovery_model_desc
   ,PhysicalName = f.physical_name
from
    sys.database_files as f
	inner join sys.databases as db
        on db.database_id = db_id()'
from
    sys.databases as d

insert into @dbfiles exec sp_executesql @sqlcmd

select
    d.ServerName
   ,DbId
   ,d.DBName
   ,d.DBFileName
   ,d.FileType
   ,d.DBSizeMB
   ,SuggestedMB = ceiling(d.DBUsedSpaceMB / 0.9 / 64) * 64
   ,d.DBUsedSpaceMB
   ,d.DBFreeSpaceMB
   ,d.DBPctFree
   ,d.GrU
   ,d.DBGrowth
   ,d.DBState
   ,d.RecoverModel
   ,d.PhysicalName
from
    @dbfiles as d
where
    1 = 1
	--and d.DbId > 4
	--and d.TypeId <> 1 --exclude log files
	--and d.DBName = 'tempdb'
order by
    --d.DbId, d.TypeId
    --d.DBFreeSpaceMB desc
    --d.LogFreeSpaceMB desc
    d.DBName, d.TypeId
    --d.DBPctFree
    --d.DBSizeMB desc
    --d.DBGrowth
