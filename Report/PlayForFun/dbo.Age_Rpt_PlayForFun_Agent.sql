/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Rpt_PlayForFun_Agent]
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
	Task: Play For Fun - Statistics Report for Master [RedmineID: #72877]

	Revisions:

	Param's Explanation:
		@CustId: mrecommend
		@FromDate, @ToDate: date range
		@ProductId: productId
		@StatusId:
			0: enabled
			1: disabled
			2: all
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpData (CustId INT, NoOfPlayers INT, TurnOver MONEY, WinLoss MONEY, BetCount INT)

	INSERT INTO #tmpData (CustId, NoOfPlayers, TurnOver, WinLoss, BetCount)
	SELECT b.recommend, COUNT(DISTINCT b.custid), SUM(b.stake) AS TurnOver, SUM(b.winlost - b.stake) AS WinLoss, SUM(b.betcount) AS BetCount
	FROM dbo.BettransPF b WITH(NOLOCK)
	WHERE b.mrecommend = @CustId
		AND b.winlostdate BETWEEN @FromDate AND @ToDate
		AND (
			@StatusId = 2 -- get all
			OR (
				@StatusId <> 2
				AND (
					(@ProductId = 6 AND EXISTS(SELECT 1 FROM dbo.custInfo c WITH(NOLOCK) WHERE c.custid = b.custid AND c.DisableCasino = @StatusId))
					OR (
						@ProductId <> 6
						AND EXISTS(
							SELECT 1
							FROM dbo.ProductSettingDetail psd WITH(NOLOCK)
								INNER JOIN dbo.ProductStatusProfile psp WITH(NOLOCK) ON psd.SportType = psp.Sporttype AND psd.BetType = psp.Bettype
								CROSS APPLY (
									SELECT cps.CustId, cps.bitmapIsDisabled FROM dbo.CustProductStatus cps WITH(NOLOCK)
									WHERE cps.CustId = b.custid
								) c
							WHERE psd.ProductID = @ProductId
								AND dbo.f_GetProductStatus(c.bitmapIsDisabled, psp.bitmapOrder) = @StatusId
						)
					)
				)
			)
		)
	GROUP BY b.recommend

	SELECT t.CustId, c.username, NoOfPlayers, t.TurnOver, t.WinLoss, t.BetCount
	FROM #tmpData t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.CustId = c.custid
	ORDER BY NoOfPlayers DESC

	DROP TABLE #tmpData
END
GO