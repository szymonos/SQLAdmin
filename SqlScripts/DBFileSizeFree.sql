/*
use dbname;
go
--dbcc shrinkfile(N'db_log', 0, truncateonly) --truncate all
dbcc shrinkfile(N'db_log', 10240) --reorganize and shrink to size MB
*/

select
    pt.DBName
   , pt.DataFileName
   , [DataSize (GB)] = cast([Data File(s) Size (KB)] * 1.0 / (1024 * 1024) as decimal(18, 2))
   , convert(char(16), pt.DataBackupDate, 120) as DataBackupDate
   , pt.LogFileName
   , [LogSize (GB)] = cast([Log File(s) Size (KB)] * 1.0 / (1024 * 1024) as decimal(18, 2))
   , [FreeLog (GB)] = cast(([Log File(s) Size (KB)] - [Log File(s) Used Size (KB)]) * 1.0 / (1024 * 1024) as decimal(18, 2))
   , [LogUsed (GB)] = cast([Log File(s) Used Size (KB)] * 1.0 / (1024 * 1024) as decimal(18, 2))
   , LogPct = cast([Percent Log Used] as varchar(3)) + '%'
   , RecoveryModel = pt.recovery_model_desc
   , convert(char(16), pt.LogBackupDate, 120) as LogBackupDate
   , pt.log_reuse_wait_desc
from (select os.counter_name , DBName = db.name , os.cntr_value , db.recovery_model_desc , db.log_reuse_wait_desc , DataFileName = df.name , LogFileName = lf.name , dbd.DataBackupDate , lbd.LogBackupDate
    from sys.dm_os_performance_counters as os join sys.databases as db on os.instance_name = db.name inner join sys.sysaltfiles as df on df.groupid = 1 and db.database_id = df.dbid inner join sys.sysaltfiles as lf on lf.groupid = 0 and db.database_id = lf.dbid
        left outer join (select b.database_name , LogBackupDate = cast(max(b.backup_finish_date) as smalldatetime)
        from msdb.dbo.backupset as b
        where b.type = 'L'
        group by b.database_name) as lbd on os.instance_name = lbd.database_name
        left outer join (select b.database_name , DataBackupDate = cast(max(b.backup_finish_date) as smalldatetime)
        from msdb.dbo.backupset as b
        where b.type = 'D'
        group by b.database_name) as dbd on os.instance_name = dbd.database_name
    where os.counter_name in ('Data File(s) Size (KB)' ,'Log File(s) Size (KB)' ,'Log File(s) Used Size (KB)' ,'Percent Log Used' ) and db.database_id > 4 ) as SourceTable
pivot ( max(cntr_value) for counter_name in ([Data File(s) Size (KB)] ,[Log File(s) Size (KB)] ,[Log File(s) Used Size (KB)] ,[Percent Log Used] ) ) as pt
order by RecoveryModel desc, DBName
--order by [Log File(s) Size (KB)] desc, DBName
