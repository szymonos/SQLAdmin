drop table if exists #disabledUsers;

create table #disabledUsers (
    NTAccount varchar(40) not null
   ,UserName nvarchar(100) not null
);

insert into #disabledUsers with(tablock) (NTAccount, UserName)
select 'domain1\' + SAMAccountName as NTAccount, Name
from openquery(ADSI, '
    select SAMAccountName, userAccountControl, Name
    from ''LDAP://domain1.com.pl/OU=Special Accounts, DC=domain1,DC=com,DC=pl''
    where objectCategory = ''Person'' and objectClass = ''user'' and ''userAccountControl:1.2.840.113556.1.4.803:''=2
'	 ) as tblADSI
union all
select 'domain2\' + SAMAccountName as NTAccount, Name
from openquery(ADSI, '
    select SAMAccountName, userAccountControl, Name
    from ''LDAP://domain2.com/OU=Special Accounts,DC=domain2,DC=com''
    where objectCategory = ''Person'' and objectClass = ''user'' and ''userAccountControl:1.2.840.113556.1.4.803:''=2
'	 ) as tblADSI;

create nonclustered index IX_NTAccount on #disabledUsers(NTAccount);

select u.NTAccount, u.UserName from #disabledUsers as u
