﻿select
    TableName = t.name
   ,SchemaName = s.name
   ,RowCounts = p.rows
   ,TotalSpaceKB = sum(a.total_pages) * 8
   ,TotalSpaceMB = cast(round(((sum(a.total_pages) * 8) / 1024.00), 2) as numeric(36, 2))
   ,UsedSpaceKB = sum(a.used_pages) * 8
   ,UsedSpaceMB = cast(round(((sum(a.used_pages) * 8) / 1024.00), 2) as numeric(36, 2))
   ,UnusedSpaceKB = (sum(a.total_pages) - sum(a.used_pages)) * 8
   ,UnusedSpaceMB = cast(round(((sum(a.total_pages) - sum(a.used_pages)) * 8) / 1024.00, 2) as numeric(36, 2))
from
    sys.tables as t
    inner join sys.indexes as i
        on t.object_id = i.object_id
    inner join sys.partitions as p
        on i.object_id = p.object_id and i.index_id = p.index_id
    inner join sys.allocation_units as a
        on p.partition_id = a.container_id
    left outer join sys.schemas as s
        on t.schema_id = s.schema_id
where
    t.is_ms_shipped = 0 and i.object_id > 255
--    t.name like 'PLL%' and t.is_ms_shipped = 0 and i.object_id > 255
group by
    t.name
   ,s.name
   ,p.rows
order by
    p.rows desc
