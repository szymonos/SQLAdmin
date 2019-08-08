select
    r.restore_history_id
   ,r.restore_date
   ,r.destination_database_name
   ,r.user_name
   ,type_desc = case r.restore_type
                    when 'D' then 'Database'
                    when 'F' then 'file'
                    when 'G' then 'Filegroup'
                    when 'I' then 'Differential'
                    when 'L' then 'Log'
                    when 'V' then 'Verifyonly'
                    else r.restore_type end
   ,r.replace
   ,rec_model = d.recovery_model_desc
   ,recovery = case r.recovery when 1 then 'RECOVERY' when 0 then 'NORECOVERY' else null end
   ,r.restart
   ,r.stop_at
from
    msdb.dbo.restorehistory as r
    inner join (
		select
			r.restore_history_id
		   ,rownum = row_number() over (partition by r.destination_database_name order by r.restore_history_id desc)
		from
			msdb.dbo.restorehistory as r) as rn on rn.restore_history_id = r.restore_history_id
    inner join sys.databases as d
        on d.name = r.destination_database_name
where
    1 = 1
	and rn.rownum = 1
order by
    r.restore_date desc
