/*Na produkcji - inserty konfiguracji*/
select 'insert into #configprod (prodname,prodvalue) values (' + '''' + cast(name as nvarchar(35)) + '''' + ',' + '''' + cast(value as nvarchar(35)) + '''' + ')' from sys.configurations

/* Na nowym serwerze */
drop table if exists #configprod;
create table #configprod (id int identity, prodname nvarchar(35), prodvalue nvarchar(35));
drop table if exists #configtest;
create table #configtest (id int identity, testname nvarchar(35), testvalue nvarchar(35));
declare @conf_id int ,@testname nvarchar(35) ,@testvalue nvarchar(35)
declare server_config cursor fast_forward for
select c.configuration_id
from sys.configurations as c
open server_config
fetch next from server_config into @conf_id
while @@fetch_status = 0
begin
    select @testname = c.name, @testvalue = cast(c.value as nvarchar(35)) from sys.configurations as c where c.configuration_id = @conf_id
	exec ('insert into #configtest (testname,testvalue) values (' + '''' + @testname + '''' + ',' + '''' + @testvalue + '''' + ')')
    fetch next from server_config into @conf_id
end
close server_config
deallocate server_config

/* Porównanie konfiguracji */
select *, 'exec sp_configure ' + '''' + a.prodname + '''' + ',' + '''' + a.prodvalue + ''''
from #configprod as a full join #configtest as b on a.prodname = b.testname
where a.prodvalue <> b.testvalue
union
select null, null, null, null, null, null, 'reconfigure'
union
select null, null, null, null, null, null, 'exec sp_configure ''show advanced options'',''1'''
union
select null, null, null, null, null, null, 'exec sp_configure ''show advanced options'',''0'''

/*
truncate table #configprod;
truncate table #configtest;
*/
