declare @ProductVersion sysname, @MajorVersion int, @sqlcmd nvarchar(max);
/* Use ProductVersion instead of ProductMajorVersion for SQL Editions before SQL 2012 */
set @ProductVersion = isnull(cast(serverproperty('ProductVersion') as sysname), '0.')
set @MajorVersion = cast(left(@ProductVersion, charindex('.', @ProductVersion) - 1) as int)

select
    SQLServerName = serverproperty('ServerName')
   ,SQLMachineName = serverproperty('MachineName')
   ,InstanceName = isnull(serverproperty('InstanceName'), 'MSSQLSERVER')
   ,ClusterNodeName = serverproperty('ComputerNamePhysicalNetBIOS')
   ,ServerVersion = case
                        when charindex('-', @@VERSION) < charindex('(', @@VERSION) then left(@@version, charindex('-', @@version) - 2)
                        else left(@@version, charindex('(', @@version) - 2)end
   ,ProductLevel = serverproperty('ProductLevel')
   ,UpdateLevel = serverproperty('ProductUpdateLevel')
   ,KB = serverproperty('ProductUpdateReference')
   ,ProductVersion = serverproperty('ProductVersion')
   ,ServerEdition = serverproperty('Edition')
   ,IsClustered = serverproperty('IsClustered')

if (@MajorVersion > 10)
begin
	/* Services */
    select
        SQLServerName = serverproperty('ServerName')
       ,ss.servicename
       --,ss.startup_type
       ,ss.startup_type_desc
       ,ss.service_account
       --,ss.status
       ,ss.status_desc
       ,last_startup = cast(ss.last_startup_time as datetime)
       ,ss.filename
       ,ss.process_id
    from
        sys.dm_server_services as ss;

	/* OS/Machine Info */
	set @sqlcmd = N'select top(1) SQLServerName = serverproperty(''ServerName''), LocalAddress = c.local_net_address, LocalPort = c.local_tcp_port, CPUs = i.cpu_count, MemoryGB = i.physical_memory_kb / 1048576, TargetMemGB = i.visible_target_kb / 1048576, SystemVersion = substring(@@version, charindex('') on'', @@version) + 5, 255)
	from sys.dm_exec_connections as c cross join sys.dm_os_sys_info as i
	where c.local_tcp_port is not null;'
end
else
begin
	declare @sqlsrv sysname, @sqlagent sysname;
	exec master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\CurrentControlSet\services\SQLSERVERAGENT', 'ObjectName', @sqlagent output;
	exec xp_regread @root_key = 'HKEY_LOCAL_MACHINE', @key = 'SYSTEM\ControlSet001\Services\MSSQLServer', @valuename = 'ObjectName', @value = @sqlsrv output
	select SQLServerName = serverproperty('ServerName'), SQLServiceAccount = @sqlsrv, SQLAgentServiceAccount = @sqlagent;

	set @sqlcmd = N'select top(1) SQLServerName = serverproperty(''ServerName''), LocalAddress = c.local_net_address, LocalPort = c.local_tcp_port, CPUs = i.cpu_count, MemoryGB = i.physical_memory_in_bytes / 1073741824, SystemVersion = substring(@@version, charindex('') on'', @@version) + 5, 255)
	from sys.dm_exec_connections as c cross join sys.dm_os_sys_info as i
	where c.local_tcp_port is not null;'
end

exec sys.sp_executesql @sqlcmd
