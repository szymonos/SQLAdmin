set nocount on;

declare
    @check bit = 1							--check query (print)
   ,@existing bit = 1						--restore existing databases
   ,@backup_date varchar(8) = ''			--select backup date in format yyyyMMdd, put '' to restore latest backup
--   ,@backup_date varchar(8) = '20190806'
   ,@bakFromDir sysname = '\\ServerName\DB_Backups'
   ,@bak_location sysname
   ,@pscmd nvarchar(200)
   ,@restoreQuery nvarchar(max) = N''
   ,@db_name sysname
   ,@sql_cmd nvarchar(max)
   ,@server_name sysname;

declare @tbl_FoldersFiles table (ff varchar(256) null)

declare @tbl_Backups table (dbName varchar(20) not null, bakName varchar(200) not null)

set @server_name = cast(serverproperty('MachineName') as sysname)

set @pscmd = 'powershell.exe -NoLogo -NoProfile -Command "C:\Inst\Scripts\LatestFilesInFolders.ps1" -SourcePath "' + @bakFromDir
if @backup_date <> ''
	set @pscmd += '" -BackupDate "' + @backup_date + '"'

insert into @tbl_FoldersFiles (ff) exec master.dbo.xp_cmdshell @pscmd

insert into @tbl_Backups (dbName, bakName)
select
    dbName = left(a.ff, charindex(',', a.ff) - 1)
   ,bakName = right(a.ff, len(ff) - charindex(',', a.ff))
from
    @tbl_FoldersFiles as a
    left outer join sys.databases as d
        on d.name = left(a.ff, charindex(',', a.ff) - 1)
where
    ff is not null

declare db_cur cursor local fast_forward for
select
    b.dbName
   ,b.bakName
from
    @tbl_Backups as b
    inner join sys.databases as d
        on d.name = b.dbName
where
    d.database_id is null
    or
    (d.database_id > 4 and d.name not in ('DBName', 'SSISDB'))
--    d.name in ('DBName', 'SSISDB')

open db_cur;

fetch next from db_cur
into
    @db_name
   ,@bak_location;

while @@fetch_status = 0
begin
    if @existing = 1
    begin
        set @sql_cmd = N'alter database ' + @db_name + N' set single_user with rollback immediate' + char(13) + char(10) +
		 N'restore database ' + @db_name + N' from disk = N''' + @bak_location + N''' with file = 1, nounload, replace, stats = 5'
		 + char(13) + char(10) + N'alter database ' + @db_name + N' set multi_user'
    end else
	begin
		set @sql_cmd = N'restore database ' + @db_name + N' from disk = N''' + @bak_location + N''' with file = 1, nounload, stats = 5'
    end
    /* Change database recovery model to simple */
	set @sql_cmd += char(13) + char(10) + N'alter database ' + @db_name + N' set recovery simple with no_wait'

    if @check = 1 print @sql_cmd;
    else
    begin try
        exec sys.sp_executesql @sql_cmd;
    end try
    begin catch
        select serverproperty('ServerName'), error_message();
    end catch;

    fetch next from db_cur
    into
        @db_name
       ,@bak_location;
end;

close db_cur;
deallocate db_cur;
