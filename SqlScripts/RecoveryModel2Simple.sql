use master;
go

declare
    @check bit = 1 --check query (print)
   ,@db_name sysname
   ,@sql_cmd nvarchar(max);

declare db_cur cursor local fast_forward for
select
    d.name
from
    sys.databases as d
where
    d.database_id > 4 and d.recovery_model = 1 and state = 0; --recovery_model 1 - FULL; state 0 - ONLINE

open db_cur;

fetch next from db_cur
into
    @db_name;

/* Change database recovery model to simple */
while @@fetch_status = 0
begin
    set @sql_cmd = N'alter database ' + @db_name + N' set recovery simple with no_wait';

    if @check = 1 print @sql_cmd;
    else
    begin try
        exec sys.sp_executesql @sql_cmd;

        print 'Recovery model on database ' + @db_name + ' has been changed';
    end try
    begin catch
        select serverproperty('ServerName'), error_message();
    end catch;

    fetch next from db_cur
    into
        @db_name;
end;

close db_cur;
deallocate db_cur;
