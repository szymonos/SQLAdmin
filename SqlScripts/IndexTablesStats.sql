use DBName;
go

select
    TableId = cast(o.object_id as nvarchar(10))
   , SchemaTable = s.name + '.' + o.name
   , IndexId = cast(i.index_id as nvarchar(10))
   , IndexName = i.name
   , IndexType = i.type
   , IndexSizeMB = cast(sum(p.used_page_count) * 1.0 / 128 as decimal(15, 2))
   , Row_Count = sum(p.row_count)
into
    #t2c
from
    sys.objects as o
    inner join sys.schemas as s
    on s.schema_id = o.schema_id
    inner join sys.indexes as i
    on i.object_id = o.object_id
    inner join sys.dm_db_partition_stats as p
    on p.object_id = i.object_id and p.index_id = i.index_id
where
    o.name in ('table1', 'table2')
    and o.type = 'U'
group by
    o.object_id
   ,o.name
   ,s.name
   ,i.index_id
   ,i.name
   ,i.type;

declare @sqlcmd nvarchar(max) = N'';

select @sqlcmd += N'union all
select
    TableName = ' + quotename(SchemaTable, '''') + '
   ,TableRows = ' + cast(max(Row_Count) as varchar(10)) + N'
   ,TableSizeMB = ' + cast(sum(IndexSizeMB) as varchar(10)) + N'
   ,LastUpdated = cast(min(last_updated) as char(19))
   ,StatsUpdate = ''use ' + db_name(db_id()) + '; update statistics ' + SchemaTable + ' with sample 100 percent;''
from
	sys.stats as s
    cross apply sys.dm_db_stats_properties(s.object_id, s.stats_id) as sp
where
    s.object_id = ' + TableId + N'
'
from
    #t2c
group by
    TableId, SchemaTable;

set @sqlcmd = stuff(@sqlcmd, 1, 11, '') + N'order by LastUpdated';

exec sp_executesql @sqlcmd;

set @sqlcmd = N'';

select
    @sqlcmd += N'union all
select
    TableName = ' + quotename(SchemaTable, '''') + N'
   ,IndexName = ' + quotename(IndexName, '''') + N'
   ,IndexRows = ' + quotename(Row_Count, '''') + N'
   ,IndexSizeMB = ' + quotename(IndexSizeMB, '''') + N'
   ,FragmentationPct = cast(s.avg_fragmentation_in_percent as decimal(5,1))
   ,DefragIndexes = ''use ' + db_name(db_id()) + N'; alter index ' + IndexName + N' on ' + SchemaTable
               + N' rebuild with (online = on);''
from
    sys.dm_db_index_physical_stats(db_id(), ' + TableId + N', ' + IndexId + N', null, null) as s

where
	s.avg_fragmentation_in_percent > 1
'
from
    #t2c
where
    IndexType > 0;

set @sqlcmd = stuff(@sqlcmd, 1, 11, '') + N'order by FragmentationPct desc';

--print @sqlcmd
exec sp_executesql @sqlcmd;

drop table if exists #t2c;
