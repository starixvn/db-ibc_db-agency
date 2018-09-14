/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetailPokerGames_Member]
	@CustID			INT = NULL, --recommend
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ProductIds		VARCHAR(MAX) =33 ,
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
	Original SP: Age_Rpt_WinLossDetail_Member
	Revisions:
		 
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RowStart	INT,
			@RowEnd		INT;
		
	SELECT	@PageIndex = @PageIndex - 1,
			@RowStart = @PageSize * @PageIndex + 1,
			@RowEnd = @RowStart + @PageSize - 1;
 
	CREATE TABLE #AgWinLossDetails(
		CustID				INT,
		TurnOver			MONEY,
		NetTurnover			MONEY,
		TaxComm				MONEY,
		TotalMemberWinLoss	MONEY,
		MemberWinLoss		MONEY,
		InsGemMemberWinLoss	MONEY,
		PlayerComm			MONEY,
		AgWinLoss			MONEY,
		AgComm				MONEY,
		RoundCount			INT
	);

	--Avoid Parameter Sniffing
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME,
			@CID	INT;
	    
	SELECT	@FDate = @FromDate,
			@TDate = @ToDate, 
			@CID = @custid;

			
	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);	
	
	DECLARE @SportBettypeMatrix TABLE(BetType smallint);

	INSERT INTO @SportBettypeMatrix(BetType)
	SELECT	DISTINCT BetType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) f 

	IF @ToDate >= @BalanceUpDay
	BEGIN 
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END

		INSERT INTO #AgWinLossDetails(CustID, TurnOver, NetTurnover, TaxComm, TotalMemberWinLoss, MemberWinLoss, InsGemMemberWinLoss, PlayerComm, AgWinLoss, AgComm, RoundCount)
		SELECT	CustID,
				SUM(ABS(b.stake)) as Turnover,				
				SUM(CASE WHEN b.bettype = 1499 THEN ABS(b.stake) ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p33/@to)[1]','MONEY'), 0) END ) AS NetTurnover,
				SUM(ISNULL(b.oddsspread,0)) as TaxComm,
				SUM(winlost - actual_stake) AS TotalMemberWinLoss,
				SUM(b.winlost - b.actual_stake) - SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS MemberWinLoss,
				SUM(ISNULL(b.TransID2,0)/ CONVERT(DECIMAL(19,8),10000)) AS InsGemMemberWinLoss,
				SUM(ISNULL(b.playercomm,0)) AS PlayerComm,				
				SUM(b.awinlost) AS InsGemAgWinLoss,
				SUM(ISNULL(b.comm,0)) - SUM(ISNULL(b.playercomm,0)) AS AgComm,							
				SUM(ISNULL(b.BetId,0)) AS RoundCount
		FROM dbo.bettrans b WITH(NOLOCK)			
		WHERE winlostdate BETWEEN @FDate AND @TDate
			AND b.statusID IN (111,112,113)
			AND Recommend = @CID	 
			AND EXISTS (SELECT 1 FROM @SportBettypeMatrix s WHERE b.bettype = s.Bettype)
		GROUP BY CustID, b.bettype;

		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END
		
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END
		
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, NetTurnover, TaxComm, TotalMemberWinLoss, MemberWinLoss, InsGemMemberWinLoss, PlayerComm, AgWinLoss, AgComm, RoundCount)
		SELECT	CustID,			
				SUM(TurnOver) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TotalComm) AS TaxComm,
				SUM(WinLoss) AS TotalMemberWinLoss,
				SUM(WinLoss) - SUM (InsGemMemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(playercomm) AS PlayerComm,
				SUM(AgWinLoss) AS InsGemAgWinLoss,
				SUM(AgComm) - SUM(PlayerComm) AS AgComm,
				SUM(RoundCount) AS RoundCount
		FROM bodb_Summary.dbo.rptPokerGamesSumWinloss b WITH(NOLOCK)			
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND recommend = @CID
			AND RoleID = 1
		GROUP BY CustID;
	END

	SELECT	@FDate = @FromDate,
			@TDate = @ToDate;

	IF @FromDate < @BalanceUpDay 
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
		BEGIN
			SELECT @TDate = DATEADD(dd, -1, @BalanceUpDay);
		END
	
		INSERT INTO #AgWinLossDetails(CustID, TurnOver, NetTurnover, TaxComm, TotalMemberWinLoss, MemberWinLoss, InsGemMemberWinLoss, PlayerComm, AgWinLoss, AgComm, RoundCount)
		SELECT	CustID,			
				SUM(TurnOver) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TotalComm) AS TaxComm,
				SUM(WinLoss) AS TotalMemberWinLoss,
				SUM(WinLoss) - SUM (InsGemMemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(playercomm) AS PlayerComm,
				SUM(AgWinLoss) AS InsGemAgWinLoss,
				SUM(AgComm) - SUM(PlayerComm) AS AgComm,
				SUM(RoundCount) AS RoundCount
		FROM bodb_Summary.dbo.rptPokerGamesSumWinloss_Old b WITH(NOLOCK)			
		WHERE winlostdate BETWEEN @FDate AND @TDate			
			AND recommend = @CID
			AND RoleID = 1
		GROUP BY CustID;
	END

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT	w.CustID AS CustId, 
				c.UserName AS CustName,
				SUM(Turnover) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TaxComm) AS TaxComm,
				SUM(TotalMemberWinLoss) AS TotalMemberWinLoss,
				SUM(MemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinLoss) AS AgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(RoundCount) AS RoundCount
		FROM #AgWinLossDetails w 
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		GROUP BY w.CustID, c.UserName
		ORDER BY c.Username;

		SELECT	NULL AS CustId,
				'Total' AS CustName,
				SUM(Turnover) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TaxComm) AS TaxComm,
				SUM(TotalMemberWinLoss) AS TotalMemberWinLoss,
				SUM(MemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinLoss) AS AgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(RoundCount) AS RoundCount
		FROM #AgWinLossDetails;

		RETURN;
	END

	IF @TotalRecords = 0  
	BEGIN  
		SELECT @TotalRecords = COUNT(tmp.CustID)
		FROM (
			SELECT CustID
			FROM #AgWinLossDetails
			GROUP BY CustID
		) tmp;
	END

	SELECT wl.*
	FROM (
		SELECT	w.CustID AS CustId,
				c.UserName AS CustName,
				SUM(Turnover) AS Turnover,
				SUM(NetTurnover) AS NetTurnover,
				SUM(TaxComm) AS TaxComm,
				SUM(TotalMemberWinLoss) AS TotalMemberWinLoss,
				SUM(MemberWinLoss) AS MemberWinLoss,
				SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
				SUM(PlayerComm) AS MemberComm,
				SUM(AgWinLoss) AS InsGemAgWinLoss,
				SUM(AgComm) AS AgComm,
				SUM(RoundCount) AS RoundCount,
				ROW_NUMBER() OVER (ORDER BY c.UserName) AS RowNum	
		FROM #AgWinLossDetails w 
			INNER JOIN dbo.custInfo c WITH(NOLOCK) ON w.CustID = c.CustID 
		GROUP BY w.CustID, c.UserName
	) wl
	WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

	SELECT	NULL AS CustId,
			'Total' AS CustName,
			SUM(Turnover) AS Turnover,
			SUM(NetTurnover) AS NetTurnover,
			SUM(TaxComm) AS TaxComm,
			SUM(TotalMemberWinLoss) AS TotalMemberWinLoss,
			SUM(MemberWinLoss) AS MemberWinLoss,
			SUM(InsGemMemberWinLoss) AS InsGemMemberWinLoss,
			SUM(PlayerComm) AS MemberComm,
			SUM(AgWinLoss) AS InsGemAgWinLoss,
			SUM(AgComm) AS AgComm,
			SUM(RoundCount) AS RoundCount
	FROM #AgWinLossDetails;

	DROP TABLE #AgWinLossDetails; 

	SET NOCOUNT OFF;
END
GO


GRANT EXECUTE ON [Age_Rpt_WinLossDetailPokerGames_Member] TO bodbDownlineNetView
GO 
GRANT EXECUTE ON [Age_Rpt_WinLossDetailPokerGames_Member] TO bodbDownlineNet
GO