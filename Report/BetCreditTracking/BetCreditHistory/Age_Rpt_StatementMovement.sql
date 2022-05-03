/*<info serverAlias="DBBAH-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Age_Rpt_StatementMovement
(
	@FromDate DATETIME,
	@Todate DATETIME,
	@UserName VARCHAR(30) = '',
	@LoggedId INT = -1,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMess VARchar(1000) = '' OUTPUT
)
AS
/*
	Created: Sol@20220222  
	Task: 167296 - Alpha - Avoid confusion when event date is moved
	DB: DBBAH/bodb02
	Revisions:  
		- 20220222@Sol: Initialize sp - [RedmineID: #167296] 
	
*/
BEGIN

	DECLARE 
		@InternalFromDate DATETIME,
		@InternalToDate DATETIME,
		@CustId INT = NULL,
		@IsEnabled BIT = 0,
		@LoggedRoleId TINYINT,
		@BalanceUpDate SMALLDATETIME, 
		@MoveBetsDate SMALLDATETIME

	---get mb/balanceup date
	DECLARE @MBBU TABLE (BalanceUpDate SMALLDATETIME, MoveBetsDate SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDate, MoveBetsDate)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @BalanceUpDate = BalanceUpDate, @MoveBetsDate = MoveBetsDate
	FROM @MBBU

	SELECT @InternalFromDate = @FromDate, @InternalToDate = @Todate

	SELECT @LoggedRoleId = c.roleid
	FROM dbo.Customer c WITH(NOLOCK)
	WHERE c.custid = @LoggedId

	----validate user
	IF (@UserName <> '' AND @UserName IS NOT NULL)
	BEGIN
		SELECT @CustId = custId
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.username = @UserName

		--member not exist
		IF ((@CustId IS NULL))
		BEGIN
			SELECT 1, @UserName, @CustId
			SELECT @ErrorCode = 101, @ErrorMess = 'Invalid member'
			RETURN
		END

		SELECT @IsEnabled = c.Enabled
		FROM dbo.custInfo c WITH(NOLOCK)
		WHERE c.custid = @CustId

		--member is disabled
		IF (@IsEnabled = 0)
		BEGIN
			SELECT 2, @UserName, @CustId
			SELECT @ErrorCode = 101, @ErrorMess = 'Invalid member'
			RETURN
		END

		--member not under sma logged in
		IF NOT EXISTS 
		(
			SELECT 1 
			FROM dbo.Customer c WITH(NOLOCK) 
			WHERE 1 = CASE 
							WHEN @LoggedRoleId = 4 AND c.srecommend = @LoggedId THEN 1
							WHEN @LoggedRoleId = 3 AND c.mrecommend = @LoggedId THEN 1
							WHEN @LoggedRoleId = 2 AND c.recommend = @LoggedId THEN 1
							ELSE 0
						END
					AND c.custid = @CustId AND c.roleid = 1
		)
		BEGIN
			SELECT 3, @UserName, @CustId
			SELECT @ErrorCode = 101, @ErrorMess = 'Invalid member'
			RETURN
		END
	END
	----end validation

	----temp table declaration
	BEGIN
		CREATE TABLE #SportBettype (Bettype SMALLINT PRIMARY KEY)

		CREATE TABLE #DataDetail
		(
			CustId INT
			,TransId BIGINT
			,WinlostDate DATETIME
			,OldWinlostDate	DATETIME
			,Winlost MONEY
			,ActualStake MONEY
			,PlayerComm	MONEY
		)

		CREATE TABLE #SumAmount
		(
			CustId INT
			,TransId BIGINT
			,MemberWinloss MONEY
			,MemberComm MONEY
			,MemberTotal MONEY
			,IsMultipleMoved BIT
		)
		CREATE CLUSTERED INDEX IX_SumAmount ON #SumAmount(CustId, TransId)

		CREATE TABLE #Custids (CustId INT)
	END
	----end temp table

	----get sportbook bettype only
	INSERT INTO #SportBettype (Bettype)
	SELECT bettype FROM dbo.f_SportBettypeMatrix_Sel(1,0,0,2,'','',0)

	----get list of customer
	IF (@LoggedRoleId = 4) -- super
	BEGIN
		INSERT INTO #Custids(CustId)
		SELECT c.custid
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.srecommend = @LoggedId AND c.roleid = 1
	END
	ELSE IF (@LoggedRoleId = 3) -- master
	BEGIN
		INSERT INTO #Custids(CustId)
		SELECT c.custid
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.mrecommend = @LoggedId AND c.roleid = 1
	END
	ELSE IF (@LoggedRoleId = 2) -- agent
	BEGIN
		INSERT INTO #Custids(CustId)
		SELECT c.custid
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.recommend = @LoggedId AND c.roleid = 1
	END

	----remove bettype of parlay = 29, outright = 10
	DELETE FROM #SportBettype WHERE Bettype IN (10, 29)

	IF @Todate >= @BalanceUpDate
	BEGIN 
		IF @FromDate <= @MoveBetsDate
		BEGIN
			SET @InternalFromDate = DATEADD(DD, 1, @MoveBetsDate);
		END

		--range bettrans
		INSERT INTO #DataDetail(CustId, TransId, OldWinlostDate, WinlostDate, Winlost, ActualStake, PlayerComm)
		SELECT sh.CustId, sh.TransId, sh.OldWinlostDate, sh.WinlostDate, sh.Winlost, sh.ActualStake, sh.PlayerComm
		FROM dbo.StatementMovementHistory sh WITH(NOLOCK)
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = sh.MatchId
			INNER JOIN #Custids c 
				ON c.CustId = sh.CustId
		WHERE
			sh.CustId = ISNULL(@CustId, sh.CustId)
			AND EXISTS (SELECT TOP 1 1 FROM #SportBettype b WHERE sh.Bettype = b.Bettype)
			AND 
			(
				(sh.WinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
				OR (sh.OldWinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
			)
			AND m.sporttype <> 50 --removed data of cricket 

		IF @BalanceUpDate < @FromDate
		BEGIN
			SET @InternalFromDate = @FromDate
		END
		ELSE
		BEGIN
			SET @InternalFromDate = @BalanceUpDate
		END
		
		IF @ToDate > @MoveBetsDate
		BEGIN
			SET @InternalToDate = @MoveBetsDate
		END

		--range 14
		INSERT INTO #DataDetail(CustId, TransId, OldWinlostDate, WinlostDate, Winlost, ActualStake, PlayerComm)
		SELECT sh.CustId, sh.TransId, sh.OldWinlostDate, sh.WinlostDate, sh.Winlost, sh.ActualStake, sh.PlayerComm
		FROM dbo.StatementMovementHistory sh WITH(NOLOCK)
			INNER JOIN dbo.match14 m WITH(NOLOCK)
				ON m.matchid = sh.MatchId
			INNER JOIN #Custids c 
				ON c.CustId = sh.CustId
		WHERE
			sh.CustId = ISNULL(@CustId, sh.CustId)
			AND EXISTS (SELECT TOP 1 1 FROM #SportBettype b WHERE sh.Bettype = b.Bettype)
			AND 
			(
				(sh.WinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
				OR (sh.OldWinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
			)
			AND m.sporttype <> 50 --removed data of cricket 

	END

	SELECT	@InternalFromDate = @FromDate,
			@InternalToDate = @ToDate

	IF @FromDate < @BalanceUpDate 
	BEGIN
		IF @ToDate >= DATEADD(DD, -1, @BalanceUpDate)
		BEGIN
			SELECT @InternalToDate = DATEADD(DD, -1, @BalanceUpDate);
		END

		--range bk
		INSERT INTO #DataDetail(CustId, TransId, OldWinlostDate, WinlostDate, Winlost, ActualStake, PlayerComm)
		SELECT sh.CustId, sh.TransId, sh.OldWinlostDate, sh.WinlostDate, sh.Winlost, sh.ActualStake, sh.PlayerComm
		FROM dbo.StatementMovementHistory sh WITH(NOLOCK)
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH(NOLOCK)
				ON m.matchid = sh.MatchId
			INNER JOIN #Custids c 
				ON c.CustId = sh.CustId
		WHERE
			sh.CustId = ISNULL(@CustId, sh.CustId)
			AND EXISTS (SELECT TOP 1 1 FROM #SportBettype b WHERE sh.Bettype = b.Bettype)
			AND 
			(
				(sh.WinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
				OR (sh.OldWinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
			)
			AND m.sporttype <> 50 --removed data of cricket 
	END

	----sum data by transid
	INSERT INTO #SumAmount(CustId, TransId, MemberWinloss, MemberComm, MemberTotal, IsMultipleMoved)
	SELECT d.CustId, d.TransId, 
		SUM(d.Winlost - d.ActualStake) AS MemberWinloss, 
		SUM(d.PlayerComm) AS MemberComm, 
		SUM(d.Winlost - d.ActualStake + d.PlayerComm) AS MemberTotal,
		CASE WHEN COUNT(d.TransId) > 1 THEN 1 ELSE 0 END AS IsMultipleMoved
	FROM #DataDetail d
	GROUP BY d.CustId, d.TransId

	----final result to return to UI
	SELECT c.Custid, c.Username, d.TransId, d.OldWinlostDate, d.WinlostDate, s.MemberWinloss, s.MemberComm, s.MemberTotal, s.IsMultipleMoved
	FROM #DataDetail d WITH(NOLOCK)
		INNER JOIN #SumAmount s WITH(NOLOCK)
			ON d.CustId = s.CustId AND d.TransId = s.TransId
		INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON c.custid= d.CustId AND c.roleid = 1
	ORDER BY c.username, d.TransId, d.OldWinlostDate

	----remove temp tables
	DROP TABLE #SportBettype
	DROP TABLE #DataDetail
	DROP TABLE #SumAmount
	DROP TABLE #Custids

END