use dbname;
go

drop table if exists #BulkTemp

declare
    @FileName varchar(500)
   ,@sql_cmd nvarchar(max)
   ,@ID bigint
   ,@Client varchar(10)
   ,@ClientType nvarchar(100)

set @FileName = 'C:\temp\file.csv'

create table #BulkTemp (
    ID char(2)
   ,Client varchar(10)
   ,ClientType nvarchar(100)
)

set @sql_cmd = N'bulk insert #BulkTemp
from ''' + @FileName + N'''
with (
	firstrow = 2
	,fieldterminator = '',''
	,rowterminator = ''\n''
	,fire_triggers
);'

--print @sql_cmd
exec sys.sp_executesql @sql_cmd

--select * from #BulkTemp as bt where Client = 'K14199'
declare cur cursor local fast_forward for
select ID, Client, ClientType from #BulkTemp where ID <> 10

open cur

fetch next from cur
into
    @ID
   ,@Client
   ,@ClientType

while @@fetch_status = 0
begin
    exec dbo.BLCRMAttribsObjectsValuesSet @Client, @ClientType

    fetch next from cur
    into
        @ID
       ,@Client
       ,@ClientType
end

close cur
deallocate cur
