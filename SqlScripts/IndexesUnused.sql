use DbName;
go

select sqlserver_start_time from sys.dm_os_sys_info

select
    object_schema_name(i.object_id) as SchemaName
   ,object_name(i.object_id) as ObjectName
   ,i.name as IndexName
   ,i.type_desc as IndexType
   ,i.user_updates as UserUpdates
   ,i.last_user_update as LastUserUpdate
from
    sys.indexes as i
    inner join sys.dm_db_index_usage_stats as s
        on s.object_id = i.object_id and s.index_id = i.index_id
where
    objectproperty(i.object_id, 'IsUserTable') = 1 -- User Indexes
    and s.user_seeks = 0 and s.user_scans = 0 and s.user_lookups = 0 and i.is_primary_key = 0 and i.is_unique = 0
order by
    UserUpdates desc
   ,SchemaName
   ,ObjectName
   ,IndexName
