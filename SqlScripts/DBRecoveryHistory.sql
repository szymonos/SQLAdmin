select
    b.backup_set_id
   ,convert(char(19), b.backup_start_date, 120) as backup_start_date
   ,convert(char(19), b.backup_finish_date, 120) as backup_finish_date
   ,datediff(second, b.backup_start_date, b.backup_finish_date) as backup_seconds
   ,b.machine_name
   ,b.database_name
   ,b.recovery_model
   ,d.recovery_model_desc as actual_rm
   ,b.user_name
   ,case b.type
        when 'D' then 'Database'
        when 'I' then 'Differential database'
        when 'L' then 'Log'
        when 'F' then 'File or filegroup'
        when 'G' then 'Differential file'
        when 'P' then 'Partial'
        when 'Q' then 'Differential partial'
        else b.type end as type_desc
   ,cast(b.backup_size / (1024 * 1024 * 1024) as decimal(15, 2)) as size_gb
   ,cast(b.compressed_backup_size / (1024 * 1024 * 1024) as decimal(15, 2)) as compressed_gb
   ,b.is_copy_only
   ,b.compatibility_level
   ,cast(b.backup_start_date as date) as backup_date
   ,convert(char(19), b.database_creation_date, 120) as database_creation_date
   ,m.physical_device_name
--   ,b.*
from
    msdb.dbo.backupset as b
    inner join msdb.dbo.backupmediafamily as m
        on m.media_set_id = b.media_set_id
		and m.family_sequence_number = 1
	inner join sys.databases as d
		on d.name = b.database_name
	inner join (
		select
			b.backup_set_id
		   ,b.type
		   ,rownum = row_number() over (partition by b.database_name, b.type order by b.backup_set_id desc)
		from
			msdb.dbo.backupset as b) as rn on rn.backup_set_id = b.backup_set_id and rn.type = b.type
where
    1 = 1 and b.type = 'D'
	and rn.rownum = 1
	and b.database_name not in ('master', 'model', 'msdb')
order by
	b.database_name
