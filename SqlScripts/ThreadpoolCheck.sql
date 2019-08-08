select
    is_preemptive
   ,state
   ,last_wait_type
   ,NumWorkers = count(*)
from
    sys.dm_os_workers
group by
    state
   ,last_wait_type
   ,is_preemptive
order by
    count(*) desc
go

select NumWorkers = count(*)from sys.dm_os_workers
go

/*
select * from sys.configurations as c where c.name = 'max worker threads'
*/
