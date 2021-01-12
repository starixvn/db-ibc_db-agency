/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_BonusDetail_Super]
	@SuperId		INT,
	@Username		VARCHAR(30) ='', 
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@StatusId		TINYINT= NULL,
	@IsComplained	BIT= NULL,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS

/*
Created: 20210104@Malcolm
Task : Set up Bonus feature for IBCIndo
DB: DBACC/bodb02

Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]
Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]
Param's Explanation :
	@StatusId = NULL : All
			  = 0    : Pending
			  = 1	 : Cancelled
			  = 2    : Completed
	@IsComplained =  NULL : ALL
				  =  0	  : Received or SMA haven't confirmed Payment yet
				  =  1    : Not received

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
		Recommend		INT, 
		Mrecommend		INT, 
		AgentName		VARCHAR(30),
		MasterName		VARCHAR(30),
		CreatedDate		DATETIME, 
		PaymentDate		DATE, 
		StatusId		TINYINT, 
		IsComplained	BIT,
		Amount			MONEY,
		CreationDate    DATE
	)

	INSERT INTO #Result
	(
		TransId
		,CustID
		,Username
		,Recommend
		,AgentName
		,Mrecommend
		,MasterName
		,Amount
		,StatusId
		,CreatedDate
		,PaymentDate
		,IsComplained
		,CreationDate
	)
	SELECT 
		b.BonusTransId
		,b.CustID
		,c.username
		,b.Recommend
		,ag.username
		,b.Mrecommend
		,ma.username
		,b.Amount
		,b.StatusId
		,b.CreatedDate
		,b.PaymentDate
		,b.IsComplained
		,CONVERT(DATE, b.CreatedDate)
	FROM dbo.BonusTrans b WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = b.CustID
		INNER JOIN dbo.Customer Ag WITH(NOLOCK) ON Ag.custid = b.Recommend
		INNER JOIN dbo.Customer Ma WITH(NOLOCK) ON Ma.custid = b.Mrecommend
	WHERE (@Username = '' OR c.username LIKE @Username + '%')
		AND b.CreatedDate >= @FromDate
		AND b.CreatedDate < (@ToDate + 1)
		AND (@StatusId IS NULL OR b.StatusId = @StatusId)
		AND (@IsComplained IS NULL OR b.IsComplained = @IsComplained)
		AND b.Srecommend = @SuperId
	
	UPDATE r
		SET r.ID = r.NewRowNumber
	FROM 
	(
		SELECT ID, ROW_NUMBER() OVER(ORDER BY CreationDate DESC, MasterName, AgentName, CASE WHEN PaymentDate IS NULL THEN 0.5 ELSE CONVERT(INT, IsComplained) END DESC, StatusId ASC, TransId DESC) NewRowNumber
		FROM #Result r
	) r

	SELECT @TotalRecords = COUNT(*) FROM #Result

	DELETE #Result WHERE ID < @RowStart OR ID > @RowEnd

	SELECT 
		TransId
		,CreatedDate
		,CustId
		,Username
		,AgentName
		,MasterName
		,Amount
		,PaymentDate
		,StatusId
		,IsComplained
	FROM #Result
	ORDER BY ID ASC

	DROP TABLE #Result

	SET NOCOUNT OFF;
END

GO