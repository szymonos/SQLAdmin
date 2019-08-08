use master
go

declare
    @db_name sysname
   ,@principal varchar(40) = 'Domain\GroupName'
   ,@role_name varchar(40) = 'db_owner' --nazwa roli
   ,@check bit = 1 --sprawdzenie zapytania (print)
   ,@isgrant bit = 1 --1: grant permissions, 0: revoke permissions
   ,@srvstate bit = 1 --grant permissions to view server state (for sp_WhoIsActive)
   ,@viedef bit = 1 --grant view definition permissions on server
   ,@profiler bit = 1 --grant profiler permissions
   ,@roles bit = 1 --grant/revoke roles
   ,@agent bit = 1 --grant sql agent premissions
   ,@cmdshell bit = 1 --grant xp_cmdshell permissions
   ,@sql_cmd nvarchar(max)

/* Create login */
set @sql_cmd = N'if not exists (select name from sys.server_principals where name = ''' + @principal + N''')
create login [' + @principal + N'] from windows with default_database = master, default_language = us_english'

if @check = 1 print @sql_cmd
else
begin try
    exec sp_executesql @sql_cmd
end try
begin catch
    select serverproperty('ServerName'), error_message()
end catch

/* Grant View Any Definition on server */
if @viedef = 1
begin
    set @sql_cmd = N'grant view any definition to [' + @principal + N']'
    if @check = 1 print @sql_cmd else exec sp_executesql @sql_cmd
end

/* Add SQL Profiler permissions */
if @profiler = 1
begin
    set @sql_cmd = N'grant alter trace to [' + @principal + N']'
    if @check = 1 print @sql_cmd else exec sp_executesql @sql_cmd
end

/* Add SQL Profiler permissions */
if @srvstate = 1
begin
    set @sql_cmd = N'grant view server state to [' + @principal + N']'
    if @check = 1 print @sql_cmd else exec sp_executesql @sql_cmd
end

/* Add or remove from roles on databases */
if @roles = 1
begin
    declare permission_databases cursor fast_forward for
    select name
    from sys.databases
    where database_id > 4 and name not in ('Admin', 'MIG', 'SSISDB', 'SessionStateIner', 'SessionStateIntra') and state = 0 --state = 0: ONLINE

    open permission_databases

    fetch next from permission_databases
    into
        @db_name

    /* Create user in database and add user to role */
    while @@fetch_status = 0
    begin
		if @isgrant = 1
			set @sql_cmd = N'use [' + @db_name + N'];
				if not exists (select name from sys.database_principals where name = ''' + @principal + N''')
				create user [' + @principal + N'] for login [' + @principal + N']
				exec sp_addrolemember ''' + @role_name + N''', ''' + @principal + N''''
		else
			set @sql_cmd = N'use [' + @db_name + N'];
				if exists (select name from sys.database_principals where name = ''' + @principal + N''')
				alter role [' + @role_name + N'] drop member [' + @principal + N']'
		if @check = 1 print @sql_cmd
		else
        begin try
            exec sp_executesql @sql_cmd
        end try
        begin catch
            select serverproperty('ServerName'), error_message()
        end catch

        fetch next from permission_databases
        into
            @db_name
    end

    close permission_databases
    deallocate permission_databases
end

/* Add permissions to SQL Agent jobs - działa tylko na ABCUFO */
if @agent = 1
begin
    set @sql_cmd = N'use [msdb];
		if not exists (select name from sys.database_principals where name = ''' + @principal + N''')
		create user [' + @principal + N'] for login [' + @principal + N']
		exec sp_addrolemember ''db_datareader'', ''' + @principal + N'''
		exec sp_addrolemember ''SQLAgentOperatorRole'', ''' + @principal + N'''
		exec sp_addrolemember ''SQLAgentReaderRole'', ''' + @principal + N'''
		exec sp_addrolemember ''SQLAgentUserRole'', ''' + @principal + N''''

    if @check = 1 print @sql_cmd
    else
    begin try
        exec sp_executesql @sql_cmd
    end try
    begin catch
        select serverproperty('ServerName'), error_message()
    end catch
end

if @cmdshell = 1
begin
    set @sql_cmd = N'use [master];
		if not exists (select principal_id from sys.database_principals where name = ''XP_CMDSHELL'' and type = ''R'')
		create role [XP_CMDSHELL]
		grant execute on sys.xp_cmdshell to [XP_CMDSHELL]
		if not exists (select principal_id from sys.database_principals where name = ''' + @principal + N''')
		create user [' + @principal + N'] for login [' + @principal + N']
		alter role [XP_CMDSHELL] add member [' + @principal + N']'

    if @check = 1 print @sql_cmd
    else
    begin try
        exec sp_executesql @sql_cmd
    end try
    begin catch
        select serverproperty('ServerName'), error_message()
    end catch
end
