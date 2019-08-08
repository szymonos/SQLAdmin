use dbname;
go

declare @tableName sysname;

set @tableName = 'tablename';

with ixs as --index size
(
select
    ix.index_id
   ,cast(sum(p.used_page_count) * 1.0 / 128 as decimal(15, 2)) as IndexSizeMB
from
    sys.indexes as ix
    inner join sys.dm_db_partition_stats as p
        on p.object_id = ix.object_id and p.index_id = ix.index_id
where
    ix.object_id = object_id(@tableName)
group by
    ix.index_id
)
select
    s.index_id as IndexID
   ,i.name as IndexName
   ,i.type_desc as IndexType
   ,ixs.IndexSizeMB
   ,cast(s.avg_fragmentation_in_percent as decimal(4, 1)) as AvgFragmentationPct
   ,s.fragment_count as FragmentCnt
   ,cast(s.avg_fragment_size_in_pages as decimal(9, 1)) as AvgFragmentSizePages
   --   ,s.forwarded_record_count
   ,s.alloc_unit_type_desc
   ,d.name as FileGroup
   ,xc.IndexColumns
   ,ic.IncludedColumns
from
    sys.dm_db_index_physical_stats(db_id(), object_id(@tableName), null, null, null) as s
    --    sys.dm_db_index_physical_stats(db_id(), object_id(@tableName), null, null, 'SAMPLED') as s
    inner join sys.indexes as i
        on s.object_id = i.object_id and s.index_id = i.index_id
    inner join sys.filegroups as d
        on d.data_space_id = i.data_space_id
    inner join ixs
        on s.index_id = ixs.index_id
    cross apply
    (select
         stuff((select
                    ', ' + c.name
                from
                    sys.index_columns as ic
                    inner join sys.columns as c
                        on c.object_id = ic.object_id and c.column_id = ic.column_id
                where
                    ic.is_included_column = 0 and ic.object_id = i.object_id and ic.index_id = i.index_id
                order by
                    c.name
               for xml path(''), type).value('.', 'nvarchar(4000)'), 1, 2, '')) as xc(IndexColumns)
    cross apply
    (select
         stuff((select
                    ', ' + c.name
                from
                    sys.index_columns as ic
                    inner join sys.columns as c
                        on c.object_id = ic.object_id and c.column_id = ic.column_id
                where
                    ic.is_included_column = 1 and ic.object_id = i.object_id and ic.index_id = i.index_id
                order by
                    c.name
               for xml path(''), type).value('.', 'nvarchar(4000)'), 1, 2, '')) as ic(IncludedColumns)
	where
		s.alloc_unit_type_desc = 'IN_ROW_DATA'
order by
    avg_fragmentation_in_percent desc
