/*<info serverAlias="DBOST-bodb_ost" selectors="bodbDownlineNet,bodbDownlineNetView" executers="" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[strSplit_Key] (
	@string NVARCHAR(4000)
	, @splitter CHAR(1)
	)
RETURNS @res TABLE (val INT PRIMARY KEY)
AS
/*
	Created:20191021@Bobby
	Task: New Forecast at Agent Site 
	DB: DBOST.bodb_ost
	
	Revisions: 
		- 20191021@Bobby: Initialize [Redmine:114231] 
		
*/
BEGIN
	SET @string = ISNULL(@string, '')

	IF substring(@string, len(@string), 1) <> @splitter
		SET @string = @string + @splitter

	DECLARE @start INT
		, @word NVARCHAR(4000)
		, @charindex INT
		, @i INT

	SET @i = 1
	SET @start = 1
	SET @charindex = charindex(@splitter, @string, @start)

	WHILE (@charindex <> 0)
	BEGIN
		SET @word = substring(@string, @start, @charindex - @start)
		SET @start = @charindex + 1
		SET @charindex = charindex(@splitter, @string, @start)

		INSERT INTO @res
		VALUES (@word)

		SET @i = @i + 1
	END

	RETURN
END
GO


