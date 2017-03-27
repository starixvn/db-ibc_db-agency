/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Rpt_PlayForFun_Member]
	@CustId		INT,
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@ProductId	SMALLINT,
	@StatusId	TINYINT = 2
AS

/*
	Creator: Percy
	Date: 2017-03-10
	DB: DBACC.bodb02
	Task: Play For Fun - Statistics Report for Agent [RedmineID: #72877]

	Revisions:

	Param's Explanation:
		@CustId: recommend
		@FromDate, @ToDate: date range
		@ProductId: productId
		@StatusId:
			0: enabled
			1: disabled
			2: all
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpData (CustId INT, TurnOver MONEY, WinLoss MONEY, BetCount INT)

	INSERT INTO #tmpData (CustId, TurnOver, WinLoss, BetCount)
	SELECT b.CustId, SUM(b.stake) AS TurnOver, SUM(b.winlost - b.stake) AS WinLoss, SUM(b.betcount) AS BetCount
	FROM dbo.BettransPF b WITH(NOLOCK)
	WHERE b.recommend = @CustId
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
	GROUP BY b.CustId

	IF @ProductId = 6 -- RNG Casino
	BEGIN
		SELECT t.CustId, c.username, c.DisableCasino AS StatusId , t.TurnOver, t.WinLoss, t.BetCount
		FROM #tmpData t
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON t.CustId = c.custid
		WHERE
			(@StatusId = 2 OR c.DisableCasino = @StatusId)
		ORDER BY t.TurnOver DESC
	END
	ELSE -- DCS Product
	BEGIN
		;WITH Cust_Product_Status AS
		(
			SELECT c.CustId, dbo.f_GetProductStatus(c.bitmapIsDisabled, psp.bitmapOrder) AS StatusId
			FROM dbo.ProductSettingDetail psd WITH(NOLOCK)
				INNER JOIN dbo.ProductStatusProfile psp WITH(NOLOCK) ON psd.SportType = psp.Sporttype AND psd.BetType = psp.Bettype
				CROSS APPLY (
					SELECT cps.CustId, cps.bitmapIsDisabled FROM dbo.CustProductStatus cps WITH(NOLOCK)
					WHERE EXISTS (SELECT 1 FROM #tmpData t WHERE t.CustId = cps.CustId)
				) c
			WHERE psd.ProductID = @ProductId
		)
		SELECT t.CustId, c.username, cps.StatusId, t.TurnOver, t.WinLoss, t.BetCount
		FROM #tmpData t
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON t.CustId = c.custid
			INNER JOIN Cust_Product_Status cps ON t.CustId = cps.CustId
		WHERE
			(@StatusId = 2 OR (@StatusId <> 2 AND cps.StatusId = @StatusId))
		ORDER BY t.TurnOver DESC
	END

	DROP TABLE #tmpData
END
GO