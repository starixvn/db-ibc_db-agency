/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_BonusDetail_Agent]
	@AgentId		INT,
	@Username		VARCHAR(30), --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@StatusId		TINYINT,
	@IsComplained	BIT,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS

/*
Created: 
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20200104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT
			,@RowEnd	INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @Username = ISNULL(@Username, '')

	CREATE TABLE #Result 
	(
		ID				INT,
		TransId			BIGINT,
		CustId			INT, 
		Username		VARCHAR(30), 
		CreatedDate		DATETIME, 
		PaymentDate		DATE, 
		StatusId		TINYINT, 
		IsComplained	BIT,
		Amount			MONEY,
		CreationDate    DATE,
		CreationTime	TIME
	)

	INSERT INTO #Result
	(
		TransId
		,CustID
		,Amount
		,StatusId
		,CreatedDate
		,PaymentDate
		,IsComplained
		,CreationDate
		,CreationTime
	)
	SELECT 
		b.TransId
		,b.CustID
		,b.Amount
		,b.StatusId
		,b.CreationDate
		,b.PaymentDate
		,b.IsComplained
		,CONVERT(DATE, b.CreationDate)
		,CONVERT(TIME, b.CreationDate)
	FROM dbo.BonusTrans b WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = b.CustID
	WHERE (@Username = '' OR c.username LIKE @Username + '%')
		AND b.CreationDate  >= @FromDate
		AND b.CreationDate <= @ToDate
		AND (@StatusId IS NULL OR b.StatusId = @StatusId)
		AND (@IsComplained IS NULL OR b.IsComplained = @IsComplained)
		AND b.Recommend = @AgentId
	
	UPDATE r
		SET r.ID = r.NewRowNumber
	FROM 
	(
		SELECT ID, ROW_NUMBER() OVER(ORDER BY CreationDate DESC, CASE WHEN IsComplained IS NULL THEN 0.5 ELSE IsComplained END DESC, StatusId ASC, CreationTime DESC) NewRowNumber
		FROM #Result r
	) r

	SELECT @TotalRecords = COUNT(*) FROM #Result

	DELETE #Result WHERE ID < @RowStart OR ID > @RowEnd

	SELECT 
		TransId
		,CreatedDate
		,CustId
		,Username
		,Amount
		,PaymentDate
		,StatusId
		,IsComplained
	FROM #Result
	ORDER BY ID ASC

	SET NOCOUNT OFF;
END

GO