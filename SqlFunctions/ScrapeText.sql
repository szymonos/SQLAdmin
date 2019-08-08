if exists (select * from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA = 'dbo' and ROUTINE_NAME = 'ScrapeText')
   drop function dbo.DurInt2Time
go

/****** Object:  UserDefinedFunction [dbo].[ScrapeText]    Script Date: 2013-10-25 12:41:50 ******/
set ansi_nulls on
go

set quoted_identifier on
go

alter function dbo.ScrapeText (@string nvarchar(4000))
returns nvarchar(4000)
as
begin
    declare
        @text nvarchar(4000)
       ,@Pendown nchar(1)
       ,@char nchar(1)
       ,@len int
       ,@count int

    select
        @count = 0
       ,@len = 0
       ,@text = N''
       --replace line break with space
       ,@string = replace(@string, N'</p><p>', nchar(32));

    -- begin CALLOUT A
    -- Wrap the input string with tags.
    select @string = N'>' + @string + N'<'

    -- Parse out the formatting codes.
    select @len = len(@string)

    while (@count <= @len)
    begin
        select @char = substring(@string, @count, 1)

        if (@char = N'>') select @Pendown = N'Y'
        else if (@char = N'<') select @Pendown = N'N' else if (@Pendown = N'Y') select @text = @text + @char

        select @count = @count + 1
    end

    -- Replace special characters.
    --NULL
    select @text = replace(@text, nchar(0), nchar(32));

    --Horizontal Tab
    select @text = replace(@text, nchar(9), nchar(32));

    --Line Feed
    select @text = replace(@text, nchar(10), nchar(32));

    --Vertical Tab
    select @text = replace(@text, nchar(11), nchar(32));

    --Form Feed
    select @text = replace(@text, nchar(12), nchar(32));

    --Carriage Return
    select @text = replace(@text, nchar(13), nchar(32));

    --Column Break
    select @text = replace(@text, nchar(14), nchar(32));

    --Non-breaking space
    select @text = replace(@text, nchar(160), nchar(32));

    --Non-breaking space
    select @text = replace(@text, N'&#160;', nchar(32));

    --Non-breaking space
    select @text = replace(@text, N'&nbsp;', nchar(32));

    --Single quote [']
    select @text = replace(@text, N'&#39;', nchar(39));

    --Colon [:]
    select @text = replace(@text, N'&#58;', nchar(58));

    --Double quote ["]
    select @text = replace(@text, N'&quot;', nchar(34));

    --Ampersand [&]
    select @text = replace(@text, N'&amp;', nchar(38));

    --Less than [<]
    select @text = replace(@text, N'&lt;', nchar(60));

    --Greater than [>]
    select @text = replace(@text, N'&gt;', nchar(62));

    --8203 code
    --@text = replace(@text, nchar(8203), nchar(32));

    -- Trim leading and trailing blanks and duplicate spaces
    select
        @text = ltrim(rtrim(replace(replace(replace(@text, nchar(32), N'«»'), N'»«', N''), N'«»', nchar(32))))

    return @text
end
go
