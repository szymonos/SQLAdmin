select
    db_name() as db_name
	, i.object_id
   , object_schema_name(i.object_id) + '.' + object_name(i.object_id) as schema_table
   , i.name as index_name
   , i.type_desc as index_type
   , s.name as partition_scheme
   , f.name as function_name
from
    sys.indexes as i
    join sys.partition_schemes as s
    on i.data_space_id = s.data_space_id
    inner join sys.partition_functions as f
    on f.function_id = s.function_id
