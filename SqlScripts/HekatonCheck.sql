declare @sql nvarchar(max) = N''
select
    @sql += N'union all
select
   databaseName = ' + quotename(d.name, '''') + N'
   ,tableName = b.name
   ,[rowCount] = p.rows
   ,durability_desc
   ,temporal_type_desc
   ,memoryAllocatedForTableGB = cast(memory_allocated_for_table_kb * 1.0 / (1024 * 1024) as decimal(15,2))
   ,memoryUsedByTableGB = cast(memory_used_by_table_kb * 1.0 / (1024 * 1024) as decimal(15,2))
   ,memoryAllocatedForIndexesGB = cast(memory_allocated_for_indexes_kb * 1.0 / (1024 * 1024) as decimal(15,2))
   ,memoryUsedByIndexesGB = cast(memory_used_by_indexes_kb * 1.0 / (1024 * 1024) as decimal(15,2))
   ,memoryAllocated = cast((memory_allocated_for_table_kb + memory_allocated_for_indexes_kb) * 1.0 / (1024 * 1024) as decimal(15,2))
   ,memoryUsed = cast((memory_used_by_table_kb + memory_used_by_indexes_kb) * 1.0 / (1024 * 1024) as decimal(15,2))
from
    ' + d.name + N'.sys.dm_db_xtp_table_memory_stats as a
    inner join ' + d.name + N'.sys.tables as b
        on b.object_id = a.object_id
    inner join ' + d.name + N'.sys.partitions as p
        on p.object_id = b.object_id
    inner join ' + d.name + N'.sys.schemas as s
        on b.schema_id = s.schema_id
where
    p.index_id = 2
'
from
  sys.databases as d where d.database_id > 6 and d.name <> 'SSISDB'
set @sql = stuff(@sql, 1, 11, '')
--print @sql
execute sp_executesql @sql;

select
    mem.memory_clerk_address
   ,mem.type
   ,mem.name
   ,mem.memory_node_id
   ,mem.pages_kb
   ,pages_gb = cast(mem.pages_kb * 1.0 / (1024 * 1024) as decimal(15,2))
from
    sys.dm_os_memory_clerks as mem
where
    mem.type = 'MEMORYCLERK_XTP' and mem.pages_kb > 0