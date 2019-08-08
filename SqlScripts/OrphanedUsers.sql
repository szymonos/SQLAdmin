declare @SQL nvarchar(max) = N'';

set nocount on;

drop table if exists #orphan_users;

create table #orphan_users (
    db_name sysname
   ,user_name sysname
   ,type_desc nvarchar(128)
   ,create_date date
   ,drop_user_text nvarchar(200) not null
);

select
    @SQL += N'insert into #orphan_users with(tablock) (db_name, user_name, type_desc, create_date, drop_user_text)
select
     db_name = ' + quotename(name, '''') + N'
    ,p.name
	,p.type_desc
	,p.create_date
    ,' + N'''' + N'use [' + d.name + N'];' + N'drop user [' + N'''' + N' + p.name + ' + N'''' + N'];' + N'''' + N'
from
    [' + d.name + N'].sys.database_principals as p
	left outer join master.sys.syslogins as l
		on l.sid = p.sid
where
	p.authentication_type in (1, 3)
	and p.name <> ''dbo''
	and l.sid is null;
'
from
    sys.databases as d
--where    d.name not in ('master', 'tempdb', 'model', 'msdb', 'ssisdb', 'distribution');

--print @SQL;

exec sys.sp_executesql @SQL;

select
    db_name
   ,user_name
   ,type_desc
   ,create_date
   ,drop_user_text
from
    #orphan_users
order by
    db_name
   ,user_name;
