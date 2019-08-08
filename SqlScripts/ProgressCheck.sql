select
    r.session_id
   ,r.command
   ,start_time = convert(char(19), r.start_time, 120)
   ,Pct = cast(round(r.percent_complete, 1) as varchar(5)) + '%'
   ,elapsed_time = Admin.dbo.TS2Time(r.total_elapsed_time, 0)
   ,cpu_time = Admin.dbo.TS2Time(r.cpu_time, 0)
   ,estimated_time_left = Admin.dbo.TS2Time(r.estimated_completion_time, 0)
   ,estimated_completion_time = convert(char(19) ,dateadd(second, r.estimated_completion_time / 1000, getdate()), 120)
   ,s.host_name
   ,s.login_name
   ,DBName = d.name
   ,Query = t.text
   ,r.status
from
    sys.dm_exec_requests as r
    inner join sys.dm_exec_sessions as s
        on r.session_id = s.session_id
    left outer join sys.databases as d
        on s.database_id = d.database_id
    cross apply sys.dm_exec_sql_text(r.sql_handle) as t
where
	r.session_id <> @@SPID
	and r.status in ('running', 'runnable', 'suspended')
	and r.total_elapsed_time > 10000 --requests running longer than 10s
order by
	r.start_time
