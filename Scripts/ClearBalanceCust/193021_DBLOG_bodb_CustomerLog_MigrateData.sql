/*<info serverAlias="DBLOG-bodb_CustomerLog"></info>*/
/*
	Created: 20231003@Bobby
	DB: DBLOG-bodb_CustomerLog
	Task: AutoJob Enhancement - [Redmine : #193021]
*/
--DBLOG

--TODO: Migrate data from DBARC to DBLOG
DROP TABLE IF EXISTS #tmpSessionDate;
CREATE TABLE #tmpSessionDate (rIdx INT IDENTITY(1, 1), SessionDate SMALLDATETIME);

INSERT INTO #tmpSessionDate (SessionDate)
SELECT SessionDate
FROM OPENQUERY(DBARC, 'SELECT DISTINCT SessionDate FROM bodb_Archive.dbo.Age_ClearBalanceCust_ProcessHistory WITH(NOLOCK) WHERE SessionDate > ''2023-08-23''') AS rmt
ORDER BY SessionDate

DECLARE @rCount INT = 1, @rmtSQL NVARCHAR(MAX);

WHILE EXISTS (SELECT 1 FROM #tmpSessionDate WHERE rIdx = @rCount)
BEGIN

	SELECT @rmtSQL = N'
		INSERT INTO [dbo].[Age_ClearBalanceCust_ProcessHistory]
           ([SessionDate]
           ,[BatchNo]
           ,[SuperId]
           ,[FromCustId]
           ,[ToCustId]
           ,[RoleId]
           ,[Status]
           ,[Amount]
           ,[Result]
           ,[TryCount]
           ,[ModifiedTime]
           ,[StartTime]
           ,[EndTime]
           ,[Creator]
           ,[IsAllDayBalTransfer])
		SELECT [SessionDate]
           ,[BatchNo]
           ,[SuperId]
           ,[FromCustId]
           ,[ToCustId]
           ,[RoleId]
           ,[Status]
           ,[Amount]
           ,[Result]
           ,[TryCount]
           ,[ModifiedTime]
           ,[StartTime]
           ,[EndTime]
           ,[Creator]
           ,[IsAllDayBalTransfer]
		FROM OPENQUERY(DBARC, ''SELECT * FROM bodb_Archive.dbo.Age_ClearBalanceCust_ProcessHistory WITH(NOLOCK) WHERE SessionDate =''''' + FORMAT(SessionDate, 'yyyy-MM-dd')+ ''''''') AS rmt'
	FROM #tmpSessionDate
	WHERE rIdx = @rCount

	--SELECT @rCount, @rmtSQL AS [@rmtSQL]
	
	EXEC (@rmtSQL)

	SET @rCount += 1;
END
GO