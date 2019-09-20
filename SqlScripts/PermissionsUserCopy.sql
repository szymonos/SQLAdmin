set nocount on

declare
    @OldUser sysname
   ,@NewUser sysname
   ,@sqltext nvarchar(max)

---- Old User
set @OldUser = 'DOMAIN\user1'
---- New User
set @NewUser = 'DOMAIN\user2'

select
    @sqltext = N'create login ' + quotename(@NewUser)collate database_default + N' with password=N''password''
go
'

select
    @sqltext += N'create user ' + quotename(@NewUser)collate database_default + N' for login ' + quotename(@NewUser)collate database_default + N'
go
'

select
    @sqltext += N'ALTER USER ' + @NewUser collate database_default + N' WITH LOGIN = ' + @NewUser collate database_default + N'
go
'

select
    @sqltext += case when perm.state <> 'W' then perm.state_desc else 'grant' end + space(1) + perm.permission_name + space(1) + N'to' + space(1)
                + quotename(@NewUser)collate database_default + case
                                                                    when perm.state <> 'W' then space(0)
                                                                    else space(1) + 'with grant option' end + N'
go
'
from
    sys.database_permissions as perm
    inner join sys.database_principals as usr
    on perm.grantee_principal_id = usr.principal_id
where
    usr.name = @OldUser and perm.class <> 1 and perm.major_id = 0
order by
    perm.permission_name asc
   ,perm.state_desc asc

select
    @sqltext += N'exec sp_addrolemember @rolename =' + space(1) + quotename(user_name(rm.role_principal_id), '''') + N', @membername =' + space(1)
                + quotename(@NewUser, '''') + N'
go
'
from
    sys.database_role_members as rm
where
    user_name(rm.member_principal_id) = @OldUser
order by
    rm.role_principal_id asc

print @sqltext

--GRANT EXECUTE ON SCHEMA::[dbo] TO [ABCDATA\Domain-SQLDEV_Read]
select
    [--Object Level Permissions] = case when perm.state <> 'W' then perm.state_desc else 'GRANT' end + space(1) + perm.permission_name + space(1) + 'ON' + space(1)
                                   + case when perm.class not in (1, 4) then perm.class_desc + '::' else '' end
                                   + case
                                         when perm.class in (1, 6) then quotename(user_name(isnull(obj.schema_id, typ.schema_id))) + '.'
--                                         else '' end + quotename(coalesce(obj.name, sch.name, princ.name, typ.name, null))
                                         else '' end + quotename(coalesce(obj.name, sch.name, princ.name, typ.name, 'id:' + cast(perm.major_id as varchar(2))))
                                   + case
                                         when cl.column_id is null then space(0)
                                         else '(' + quotename(cl.name) + ')' end + space(1) + 'TO' + space(1) + quotename(@NewUser)collate database_default
                                   + case
                                         when perm.state <> 'W' then space(0)
                                         else space(1) + 'WITH GRANT OPTION' end
from
    sys.database_permissions as perm
    left outer join sys.objects as obj
    on perm.class = 1 and perm.major_id = obj.object_id
    left outer join sys.schemas as sch
    on perm.class = 3 and perm.major_id = sch.schema_id
    left outer join sys.database_principals as princ
    on perm.class = 4 and perm.major_id = princ.principal_id
    left outer join sys.types as typ
    on perm.class = 6 and perm.major_id = typ.user_type_id
    inner join sys.database_principals as usr
    on perm.grantee_principal_id = usr.principal_id
    left join sys.columns as cl
    on cl.column_id = perm.minor_id and cl.object_id = perm.major_id
where
    usr.name = @OldUser
    and perm.class > 0
order by
    perm.class
   ,perm.permission_name asc
   ,perm.state_desc asc
