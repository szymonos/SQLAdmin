declare @DBName varchar(64) = 'DbName'

declare @ErrorLog as table (LogDate smalldatetime, ProcessInfo varchar(64), Text varchar(max))

insert into @ErrorLog
exec master..sp_readerrorlog 0, 1, 'Recovery of database', @DBName

insert into @ErrorLog
exec master..sp_readerrorlog 0, 1, 'Recovery completed', @DBName

select top 1
    @DBName as DBName
   ,LogDate
   ,case
        when substring(Text, 10, 1) = 'c' then '100%'
        else substring(Text, charindex(') is ', Text) + 4, charindex(' complete (', Text) - charindex(') is ', Text) - 4)end as PercentComplete
   ,case
        when substring(Text, 10, 1) = 'c' then '00 00:00:00'
        else Admin.dbo.Sec2Time(cast(substring(Text, charindex('approximately', Text) + 13, charindex(' seconds remain', Text) - charindex('approximately', Text) - 13) as int), 1) end as TimeRemaining
   ,Text
from
    @ErrorLog
order by
    cast(LogDate as datetime) desc
   ,TimeRemaining
