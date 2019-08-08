declare
    @tableId int
   ,@tableName sysname;

set @tableId = 688630142 -- jeżeli równe 0 wtedy pokaże partycje tabeli wymienionej z nazwy w @tableName
set @tableName = 'tablename'

-- View Partitioned Table information
select
    object_schema_name(pstats.object_id) as SchemaName
   ,object_name(pstats.object_id) as TableName
   ,ps.name as PartitionSchemeName
   ,ds.name as PartitionFilegroupName
   ,pf.name as PartitionFunctionName
   ,case pf.boundary_value_on_right when 0 then 'Range Left' else 'Range Right' end as PartitionFunctionRange
   ,case pf.boundary_value_on_right when 0 then 'Upper Boundary' else 'Lower Boundary' end as PartitionBoundary
   ,prv.value as PartitionBoundaryValue
   ,c.name as PartitionKey
   --,case
   -- when pf.boundary_value_on_right = 0 then
   --      c.name + ' > ' + convert(varchar(19), isnull(lag(prv.value) over (partition by
   --                                                            pstats.object_id
   --                                                        order by
   --                                                            pstats.object_id
   --                                                           ,pstats.partition_number), 'Infinity'), 120) + ' and ' + c.name + ' <= '
   --      + convert(varchar(19), isnull(prv.value, 'Infinity'), 120)
   -- else c.name + ' >= ' + convert(varchar(19), isnull(prv.value, 'Infinity'), 120) + ' and ' + c.name + ' < '
   --      + convert(varchar(19), isnull(lead(prv.value) over (partition by
   --                                              pstats.object_id
   --                                          order by
   --                                              pstats.object_id
   --                                             ,pstats.partition_number), 'Infinity'), 120)end as PartitionRange
   ,pstats.partition_number as PartitionNumber
   ,pstats.row_count as PartitionRowCount
   ,p.data_compression_desc as DataCompression
from
    sys.dm_db_partition_stats as pstats
    inner join sys.partitions as p
        on pstats.partition_id = p.partition_id
    inner join sys.destination_data_spaces as dds
        on pstats.partition_number = dds.destination_id
    inner join sys.data_spaces as ds
        on dds.data_space_id = ds.data_space_id
    inner join sys.partition_schemes as ps
        on dds.partition_scheme_id = ps.data_space_id
    inner join sys.partition_functions as pf
        on ps.function_id = pf.function_id
    inner join sys.indexes as i
        on pstats.object_id = i.object_id and pstats.index_id = i.index_id and dds.partition_scheme_id = i.data_space_id and i.type <= 1 /* Heap or Clustered Index */
    inner join sys.index_columns as ic
        on i.index_id = ic.index_id and i.object_id = ic.object_id and ic.partition_ordinal > 0
    inner join sys.columns as c
        on pstats.object_id = c.object_id and ic.column_id = c.column_id
    left join sys.partition_range_values as prv
        on pf.function_id = prv.function_id
           and pstats.partition_number = (case pf.boundary_value_on_right when 0 then prv.boundary_id else (prv.boundary_id + 1) end)
where
    (@tableId = 0 and pstats.object_id = object_id(@tableName)) or pstats.object_id = @tableId
order by
    TableName
   ,PartitionNumber desc;
