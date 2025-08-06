/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv,wsv_xnap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Rpt_CashServiceBilling]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS
/*
	Created: 20250602@Virgil
	Task: Cash Service - Billing service and Report changes - Sprint 4 [RedmineId: #229883]
	DB: DBAGE-bodb02

	Revisions:
		- 20250602@Virgil: Init SP [RedmineID: #227984]
		- 20250715@Virgil: Add Promotion TransactionType [RedmineID: #232880]
		- 20250721@Virgil: Grant permission wsv_xnap and enhance code [RedmineID: #233052]
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #OutputResult(
		[FeeType]	SMALLINT,
		[Type]		SMALLINT,
		[Fee]		DECIMAL(10, 2),
		[Count]		INT
	);

	----Get @Srecommend
	DECLARE @Srecommend int, @mrecommend int;
	  
	SELECT	@Srecommend =  Srecommend,
			@Mrecommend =  Mrecommend
	FROM dbo.CustInfo c WITH(NOLOCK) 
	WHERE c.CustID = @CustID; 

	-- Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME;
	
	--/* TRANSACTION FEE */--
	-- Full range data for CashTransaction
	SELECT @FDate = @FromDate, @TDate = DATEADD(DD, 1, @ToDate)

	IF @FDate IS NOT NULL
	BEGIN
		WITH CashServiceBilling AS (
				SELECT
					CASE WHEN TransactionTypeID = 12 THEN 11 ELSE TransactionTypeID END AS TransactionTypeID,
					JSON_VALUE(ExtraInfo, '$.Fee') AS Fee,
					TransId,
					Amount
				FROM CashTransaction cs WITH (NOLOCK)
				INNER JOIN dbo.Customer cus WITH (NOLOCK) 
					ON cus.custid = cs.CustId
					AND cus.recommend = @CustID
				WHERE CAST(JSON_VALUE(ExtraInfo, '$.ChargedAt') AS SMALLDATETIME) >= @FDate 
					AND CAST(JSON_VALUE(ExtraInfo, '$.ChargedAt') AS SMALLDATETIME) < @TDate
					AND TransactionTypeID IN (1,2,3,11,12)
			)
		INSERT INTO #OutputResult([FeeType], [Type], [Fee], [Count])
		SELECT  0					AS [FeeType],
				TransactionTypeID	AS [Type],
				[Fee]				AS [Fee],
				COUNT(TransId)		AS [Count]
		FROM CashServiceBilling WITH (NOLOCK) 
		GROUP BY [TransactionTypeID], [Fee];
	END
	
	--/* CASH SERVICE FEE */--
	-- RangeType 1 & 2 for Transfer
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = MIN(FromDate) , @TDate = DATEADD(DD, 1, MAX(ToDate))
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType IN (1,2)

	IF @FDate IS NOT NULL
	BEGIN
		INSERT INTO #OutputResult([FeeType], [Type], [Fee], [Count])
		SELECT 31000						AS [FeeType],
				tr.Bettype 					AS [Type],
				ABS(WinLost-Actual_Stake)	AS [Fee],
				COUNT(tr.TransId)			AS [Count]
		FROM dbo.Transfer tr (NOLOCK)
		INNER JOIN (	
					SELECT DISTINCT ma.ProductID, ma.BetType
					FROM  dbo.SportBettypeMatrix ma WITH(NOLOCK)
					WHERE ma.ProductID = 111
						AND ma.RefTable = 4
						AND ma.BetType IN (31003,31004)
					) f ON tr.Bettype = f.BetType
		WHERE tr.winlostdate BETWEEN @FDate AND @TDate
			AND tr.CustId = @CustID
		GROUP BY tr.Bettype, ABS(WinLost-Actual_Stake)
	END

	-- RangeType 3 for sum_winloss_old range 
	SELECT @FDate = NULL, @TDate = NULL
	SELECT @FDate = FromDate , @TDate = ToDate
	FROM dbo.f_MBU_RangeDate(@FromDate, @ToDate, @BalanceUpDay, @MoveBetsDay)
	WHERE RangeType = 3

	IF @FDate IS NOT NULL
	BEGIN
		INSERT INTO #OutputResult([FeeType], [Type], [Fee], [Count])
		SELECT	31000					AS [FeeType],
				b.Bettype				AS [Type],
				ABS(winlost)			AS [Fee],
				COUNT(1)				AS [Count]
		FROM bodb_Summary.dbo.Sum_WinLoss_Old b WITH (NOLOCK)
		INNER JOIN (
				SELECT DISTINCT ma.ProductID, ma.BetType, ma.SportType
				FROM  dbo.SportBettypeMatrix ma WITH (NOLOCK)
				WHERE ma.ProductID = 111
					AND ma.RefTable = 4
					AND ma.BetType IN (31003,31004)
				) f ON b.Bettype = f.BetType
				AND b.SportType = f.SportType
		WHERE b.winlostdate BETWEEN @FDate AND @TDate
			AND srecommend = @srecommend
			AND mrecommend = @mrecommend
			AND recommend = @custid
			AND RoleID = 2
		GROUP BY b.Bettype, ABS(winlost);
	END
	
	--/* Final Result */--
	SELECT 
		[FeeType],
		[Type],
		[Fee],
		[Count],
		[Sign] * [Count] * [Fee] AS [Agent],
		-[Sign] * [Count] * [Fee] AS [Company]
	FROM (
		SELECT [FeeType],
				[Type],
				[Fee],
				SUM([Count]) AS [Count],
				CASE WHEN [Type] = 31004 THEN 1 ELSE -1 END AS [Sign]
		FROM #OutputResult
		GROUP BY [FeeType],
				[Type],
				[Fee]
	) t
	ORDER BY [FeeType] ASC

	DROP TABLE #OutputResult;
END
GO