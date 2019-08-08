declare @sql nvarchar(max) = N''

select @sql += N'union all
select
    ' + quotename(d.name, '''') + N' collate Polish_CI_AS as db_name
   ,a.name collate Polish_CI_AS as clr_name
   ,a.permission_set_desc collate Polish_CI_AS as permission_set_desc
   ,l.load_time
   ,d.is_trustworthy_on
from
    '+ quotename(name) + N'.sys.assemblies as a
    left outer join '+ quotename(name) + N'.sys.dm_clr_loaded_assemblies as l
        on l.assembly_id = a.assembly_id
	cross join sys.databases as d
where
    a.is_user_defined = 1
	and d.name = ' + quotename(d.name, '''') + N'
'
from sys.databases as d where d.database_id > 4 --and d.name <> 'SSISDB'
order by d.name
set @sql = stuff(@sql, 1, 10, '')

--print @sql
exec sp_executesql @sql

/*
alter database SSISDB set trustworthy off
alter database SSISDB set trustworthy on
*/
