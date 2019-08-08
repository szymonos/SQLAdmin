if exists (select * from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA = 'dbo' and ROUTINE_NAME = 'TS2Time')
    drop function dbo.TS2Time
go

/****** Object:  UserDefinedFunction [dbo].[TS2Time]    Script Date: 2018.07.28 11:40:56 ******/
/* Funkcja konwertująca timestamp w milisekundach na czas w formacie [d]:hh:mm:ss:[ms]			*/
/* parametr @ms włącza pokazywanie czasu w milisekuncha											*/
/* funkcja dateadd działa z dokładnością do 3.(3)ms i występują zaokrąglenia w podawanym czasie	*/

set ansi_nulls on
go

set quoted_identifier on
go

create function dbo.TS2Time (
    @wt as bigint  --time in milliseconds
   ,@ms as bit = 1 --show milliseconds
)
returns varchar(15)
as
begin
    declare @tf varchar(15)
	set @wt = abs(@wt)

    begin
        select
            @tf = case when @wt >= 8640000000 then '9X' else right('00' + cast(@wt / 86400000 as varchar(2)), 2)end + ' ' --days
                  + case
                    when @ms = 1 then stuff(convert(char(23), dateadd(ms, @wt % 86400000, 0), 121), 1, 11, '') --show with milliseconds
                    else convert(char(8), dateadd(ms, @wt % 86400000, 0), 114)               --show w/o milliseconds
                    end
    end

    return @tf
end
go
