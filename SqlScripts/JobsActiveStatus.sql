select
    p.spid
   , Duration = case
                   when datediff(second, p.login_time, getdate()) < 36000 then
                        right('00' + cast(datediff(second, p.login_time, getdate()) / 3600 as char(1)), 2)
                   else '9x' end + right(convert(char(8), dateadd(second, datediff(second, p.login_time, getdate()), 0), 108), 6)
   , job_name = j.name
   , s.step_id
   , s.step_name
   , loginame = rtrim(p.nt_username)
   , dbname = db_name(p.dbid)
   , waitresource = rtrim(p.waitresource)
   , cmd = rtrim(p.cmd)
   , p.blocked
   , QueryText = left(q.text, 444)
   , p.login_time
from
    sys.sysprocesses as p
    cross apply sys.dm_exec_sql_text(p.sql_handle) as q
    inner join msdb.dbo.sysjobsteps as s with (nolock)
    on convert(varchar(max), convert(binary(16), s.job_id), 1) = substring(p.program_name, 30, 34)
        and s.step_id = stuff(left(p.program_name, len(p.program_name) - 1), 1, 71, '')
    inner join msdb.dbo.sysjobs as j with (nolock)
    on j.job_id = s.job_id
where
    p.spid > 50 and p.program_name like 'SQLAgent - TSQL JobStep (Job %' and p.loginame <> ''