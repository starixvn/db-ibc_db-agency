/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetailPokerGames_Master]
	@CustID			INT = NULL, --srecommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) = '33',
	@BalanceUpDay	SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords	INT = 0 OUTPUT
AS

/*
	Created: 	20180912@Sophia
	Task : 		Poker Games Win Loss Detail Report [redmine: #101376]
	DB: 		DBAGE/bodb02
	Original SP: Age_Rpt_WinLossDetail_Master
	Revisions:
		-20180912@Sophia: initial SP
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT;  

	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;

	CREATE TABLE #SAgWinLossDetails
	(
		CustID				INT,
		Turnover			MONEY,
		NetTurnover			MONEY,
		TaxComm				MONEY,
		TotalMemberWinLoss	MONEY,
		MemberWinLoss		MONEY,
		InsGemMemberWinLoss	MONEY,
		PlayerComm			MONEY,
		InsGemAgWinLoss		MONEY,
		AgComm				MONEY,
		InsGemMAgWinLoss	MONEY,
		MAgComm				MONEY,
		InsGemSAgWinLoss	MONEY,
		SAgComm				MONEY,
		RoundCount			INT
	);
	 
	----Avoid Parameter Sniffing 
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate, 
			@CID = @custid;
			
	----SportBettypeMatrix		
			
	DECLARE @isTest BIT;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	
			
	DECLARE @SportBettypeMatrix TABLE(BetType SMALLINT);

	INSERT INTO @SportBettypeMatrix(BetType)
	SELECT BetType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f
		
	----Get data
	
	IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT	@TDate = @ToDate,
				@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END

		INSERT INTO #SAgWinLossDetails(CustID, Turnover, NetTurnover, TaxComm, TotalMemberWinLoss, MemberWinLoss, InsGemMemberWinLoss, PlayerComm, 
									   InsGemAgWinLoss, AgComm, InsGemMAgWinLoss, MAgComm, InsGemSAgWinLoss, SAgComm, RoundCount)
		SELECT	MRecommend,
				SUM(ABS(b.stake)) as Turnover,				
				SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
				SUM(ISNULL(b.oddsspread,0)) as TaxComm,
				SUM(b.winlost - b.actual_stake) AS TotalMemberWinLoss,
				SUM(b.winlost - b.actual_stake) - SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,
				SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,
				SUM(ISNULL(b.playercomm,0)) AS PlayerComm,
				SUM(b.awinlost) AS InsGemAgWinLoss,
				SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,
				SUM(b.mwinlost) AS InsGemMAgWinLoss,
				SUM(ISNULL(b.acomm,0)) - SUM(ISNULL(b.comm,0)) AS MAgComm,
				SUM(b.swinlost) AS InsGemSAgWinLoss,
				SUM(ISNULL(b.scomm,0)) - SUM(ISNULL(b.acomm,0)) AS SAgComm,
				SUM(ISNULL(b.BetId,0)) AS RoundCount
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE winlostdate BETWEEN @FDate AND @Tdate
			AND srecommend = @CID
			AND b.statusID IN (111, 112, 113) 
			AND EXISTS (SELECT 1 FROM @SportBettypeMatrix s WHERE b.bettype = s.Bettype)
		GROUP BY MRecommend, b.bettype;
	END 
	
	IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT  @FDate = @FromDate,
				@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
				
		INSERT INTO #SAgWinLossDetails(CustID, Turnover, NetTurnover, TaxComm, TotalMemberWinLoss, MemberWinLoss, InsGemMemberWinLoss, PlayerComm, 
									   InsGemAgWinLoss, AgComm, InsGemMAgWinLoss, MAgComm, InsGemSAgWinLoss, SAgComm, RoundCount)
		SELECT	CustID,		   --- = mrecommend	
				SUM(Turnover) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TotalComm) AS TaxComm,
				SUM(WinLoss) AS TotalMemberWinLoss,
				SUM(WinLoss) - SUM(InsGemMemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(PlayerComm) AS PlayerComm,
				SUM(AgWinLoss) AS InsGemAgWinLoss,
				SUM(AgComm) - SUM(PlayerComm) AS AgComm,
				SUM(MAgWinLoss) AS InsGemMAgWinLoss,
				SUM(MAgComm) - SUM(AgComm) AS MAgComm,
				SUM(SAgWinLoss) AS InsGemSAgWinLoss,
				SUM(SAgComm) - SUM(MAgComm) AS SAgComm,
				SUM(RoundCount) AS RoundCount
		FROM bodb_Summary.dbo.rptPokerGamesSumWinloss b WITH(NOLOCK)
		WHERE Winlostdate BETWEEN @FDate AND @TDate
			AND Srecommend = @CID
			AND RoleID = 3   
		GROUP BY CustID;
	END

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
				SUM(Turnover) as Turnover,
				SUM(NetTurnover) as NetTurnover,
				SUM(TaxComm) as TaxComm,
				SUM(TotalMemberWinLoss) as TotalMemberWinLoss,
				SUM(MemberWinLoss) as MemberWinLoss,
				SUM(InsGemMemberWinLoss) as InsGemMemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(InsGemAgWinLoss) as InsGemAgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(InsGemMAgWinLoss) as InsGemMAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(InsGemSAgWinLoss) as InsGemSAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(RoundCount) as RoundCount
		FROM #SAgWinLossDetails w 
			INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		GROUP BY w.CustID, c.UserName
		ORDER BY c.Username;

		SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(Turnover) as Turnover,
				SUM(NetTurnover) as NetTurnover,
				SUM(TaxComm) as TaxComm,
				SUM(TotalMemberWinLoss) as TotalMemberWinLoss,
				SUM(MemberWinLoss) as MemberWinLoss,
				SUM(InsGemMemberWinLoss) as InsGemMemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(InsGemAgWinLoss) as InsGemAgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(InsGemMAgWinLoss) as InsGemMAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(InsGemSAgWinLoss) as InsGemSAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(RoundCount) as RoundCount
		FROM #SAgWinLossDetails;

		RETURN;
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = count(tmp.CustID)
		FROM (
			SELECT CustID
			FROM #SAgWinLossDetails
			GROUP BY CustID
		) tmp;
 
	END

	SELECT wl.*
	FROM (
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName, 
				SUM(Turnover) as Turnover,
				SUM(NetTurnover) as NetTurnover,
				SUM(TaxComm) as TaxComm,
				SUM(TotalMemberWinLoss) as TotalMemberWinLoss,
				SUM(MemberWinLoss) as MemberWinLoss,
				SUM(InsGemMemberWinLoss) as InsGemMemberWinLoss,
				SUM(PlayerComm) as MemberComm,
				SUM(InsGemAgWinLoss) as InsGemAgWinLoss,
				SUM(AgComm) as AgComm,
				SUM(InsGemMAgWinLoss) as InsGemMAgWinLoss,
				SUM(MAgComm) as MAgComm,
				SUM(InsGemSAgWinLoss) as InsGemSAgWinLoss,
				SUM(SAgComm) as SAgComm,
				SUM(RoundCount) as RoundCount,
				ROW_NUMBER() over(order by c.UserName) as RowNum
		FROM #SAgWinLossDetails w 
			INNER JOIN dbo.custinfo c WITH(NOLOCK) ON w.CustID = c.CustID
		GROUP BY w.CustID, c.UserName
	) wl
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

	SELECT	NULL AS CustId,
			'Total' AS CustName,
			SUM(Turnover) as Turnover,
			SUM(NetTurnover) as NetTurnover,
			SUM(TaxComm) as TaxComm,
			SUM(TotalMemberWinLoss) as TotalMemberWinLoss,
			SUM(MemberWinLoss) as MemberWinLoss,
			SUM(InsGemMemberWinLoss) as InsGemMemberWinLoss,
			SUM(PlayerComm) as MemberComm,
			SUM(InsGemAgWinLoss) as InsGemAgWinLoss,
			SUM(AgComm) as AgComm,
			SUM(InsGemMAgWinLoss) as InsGemMAgWinLoss,
			SUM(MAgComm) as MAgComm,
			SUM(InsGemSAgWinLoss) as InsGemSAgWinLoss,
			SUM(SAgComm) as SAgComm,
			SUM(RoundCount) as RoundCount
	FROM #SAgWinLossDetails;

	DROP TABLE #SAgWinLossDetails;

	SET NOCOUNT OFF;
END
GO