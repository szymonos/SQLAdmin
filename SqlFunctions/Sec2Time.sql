if exists (select * from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA = 'dbo' and ROUTINE_NAME = 'Sec2Time')
    drop function dbo.Sec2Time
go

/****** Object:  UserDefinedFunction [dbo].[TimeFriendly]    Script Date: 2018.07.28 11:40:56   ******/
/****** Funkcja konwertująca sekundy na czas w formacie [d]:hh:mm:ss:[ms]						******/
/****** Parametr @sd włącza pokazywanie dni														******/
set ansi_nulls on
go

set quoted_identifier on
go

create function dbo.Sec2Time (
    @wt as int --time in seconds
   ,@sd as bit --show days
)
returns varchar(11)
as
begin
    declare @tf varchar(11)

    set @wt = abs(@wt)

    if @sd = 1
        select
            @tf
            = case when @wt >= 8640000 then '9X' else right('00' + cast(@wt / 86400 as varchar(2)), 2)end + ' '
              + right('00' + cast(@wt % 86400 / 3600 as varchar(2)), 2) + ':' + right('00' + cast(@wt % 3600 / 60 as varchar(2)), 2) + ':'
              + right('00' + cast(@wt % 60 as varchar(2)), 2)
    else
        select
            @tf
            = case when @wt >= 360000 then '9X' else right('00' + cast(@wt / 3600 as varchar(2)), 2)end + ':'
              + right('00' + cast(@wt % 3600 / 60 as varchar(2)), 2) + ':' + right('00' + cast(@wt % 60 as varchar(2)), 2)

    return @tf
end
go
