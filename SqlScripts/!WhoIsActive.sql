/*
kill 73
*/
select *
from Admin.Jobs.JobActiveStatus as a

exec dbo.sp_WhoIsActive
    @help = 0                                  -- bit, Help! What do I do?
   ,@find_block_leaders = 1                    -- bit, Walk the blocking chain and count the number of total SPIDs blocked all the way down by a given session. Also enables task_info Level 1, if @get_task_info is set to 0
   ,@show_own_spid = 0                         -- bit, Retrieve data about the calling session?
   ,@show_system_spids = 0                     -- bit, Retrieve data about system sessions?
   ,@show_sleeping_spids = 1                   -- tinyint, 0 - does not pull any sleeping SPIDs, 1 - sleeping SPIDs with open transaction, 2 - pulls all sleeping SPIDs
   ,@get_locks = 0                             -- bit, Gets associated locks for each request, aggregated in an XML format
   ,@get_task_info = 1                         -- tinyint, 0 - no task info; 1 - lightweight, non-CXPACKET wait, preference to blockers; 2 - number of active tasks, current wait stats, physical I/O, context switches, and blocker information
   ,@get_additional_info = 1                   -- bit, Get additional non-performance-related information about the session or request
   ,@get_plans = 1                             -- tinyint, 1 - gets the plan based on the request's statement offset; 2 - gets the entire plan based on the request's plan_handle
   ,@get_avg_time = 0                          -- bit, Get average time for past runs of an active query (based on the combination of plan handle, sql handle, and offset)
   ,@delta_interval = 0                        -- tinyint, Pull deltas on various metrics. Interval in seconds to wait before doing the second data pull
   ,@get_full_inner_text = 0                   -- bit, 1- gets the full text, when available; 0-  gets only the actual statement
   ,@get_outer_command = 1                     -- bit, Get the associated outer ad hoc query or stored procedure call, if available
   ,@get_transaction_info = 0                  -- bit, Enables pulling transaction log write info and transaction duration
   ,@format_output = 1                         -- tinyint, 0 - disables outfput format; 1 - formats for variable-width fonts; 2 - formats for fixed-width fonts
   ,@sort_order = '[blocked_session_count] desc, [blocking_session_id] desc, [start_time]'
   ,@output_column_list = '[dd hh:mm:ss.mss] [dd hh:mm:ss.mss (avg)] [session_id] [blocking_session_id] [blocked_session_count]
    [status] [sql_text] [sql_command] [login_name] [host_name] [database_name] [wait_info] [tasks] [tran_log_writes] [CPU]
    [CPU_delta] [tempdb_allocations] [tempdb_current] [tempdb_allocations_delta] [tempdb_current_delta] [reads] [reads_delta]
    [writes] [writes_delta] [context_switches] [context_switches_delta] [physical_io] [physical_reads] [physical_io_delta]
    [physical_reads_delta] [query_plan] [locks] [used_memory] [used_memory_delta] [tran_start_time] [open_tran_count]
    [percent_complete] [program_name] [additional_info] [start_time] [login_time] [request_id] [collection_time]'
   --,@output_column_list = '[dd hh:mm:ss.mss], [[dd hh:mm:ss.mss (avg)], [session_id], [blocking_session_id], [blocked_session_count], [status], [sql_text], [sql_command], [login_name], [program_name], [host_name], [database_name], [wait_info], [tasks], [tran_log_writes], [CPU], [CPU_delta], [tempdb_allocations], [tempdb_current], [tempdb_allocations_delta], [tempdb_current_delta], [reads], [reads_delta], [writes], [writes_delta], [context_switches], [context_switches_delta], [physical_io], [physical_reads], [physical_io_delta], [physical_reads_delta], [query_plan], [locks], [used_memory], [used_memory_delta], [tran_start_time], [open_tran_count], [percent_complete], [additional_info], [start_time], [login_time], [request_id], [collection_time]'
   --,@sort_order = '[session_id] asc'           -- varchar(500)
   --,@sort_order = '[login_name], [session_id]' -- varchar(500)
   --,@sort_order = '[login_name], [start_time]'
   --,@filter = ''                               -- sysname, Filters--Both inclusive and exclusive
   --,@filter_type = ''                          -- varchar(10), Set either filter to '' to disable
   --,@not_filter = ''                           -- sysname, Valid filter types are: session, program, database, login, and host
   --,@not_filter_type = ''                      -- varchar(10), Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
   --,@destination_table = ''                    -- varchar(4000), If set to a non-blank value, the script will attempt to insert into the specified destination table.
   --,@return_schema = 0                         -- bit
   --,@schema = @schema output                   -- varchar(max)
