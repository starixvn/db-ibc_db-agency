/*<info serverAlias="DBBAH-bodb02" executers="wsv_nap,wsv_alp,wsv_alpv" viewers="" isFunction="0"></info>*/
ALTER PROC dbo.Age_Rpt_StatementMovement
(
	@FromDate DATETIME,
	@Todate DATETIME,
	@UserName VARCHAR(30) = '',
	@LoggedId INT = -1,
	@PageIndex INT = 1,
	@PageSize INT = 100,
	@TotalRows INT = 0 OUTPUT,
	@ErrorCode INT = 0 OUTPUT,
	@ErrorMess VARchar(1000) = '' OUTPUT,
	@IsVariance BIT = 0
)
AS
/*
	Created: Sol@20220222  
	Task: 167296 - Alpha - Avoid confusion when event date is moved
	DB: DBBAH/bodb02
	Revisions:  
		- 20220222@Sol: Initialize sp - [RedmineID: #167296] 
		- 20220531@Sol: Alpha - Limit date range on Bet Credit Tracking - [RedmineID: #173447]
		- 20230615@Lewis: Alpha - Excluding SUM on MemberWinLoss, MemberComm, MemberTotal columns - [RedmineID: #189725]
		- 20230922@Lewis: Alpha - Enhance Move Statement History RPT - [RedmineID: #193722]
		- 20241119@Lewis: Direct Member [RedmineId: #211969]

	Description:
		@IsVariance : 0 view Main rpt -- 1 view Variance rpt
	
*/
BEGIN

	DECLARE 
		@InternalFromDate DATETIME,
		@InternalToDate DATETIME,
		@CustId INT = NULL,
		@IsEnabled BIT = 0,
		@LoggedRoleId TINYINT

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
			,Bettype SMALLINT
		)

		CREATE TABLE #Custids (CustId INT)

		CREATE TABLE #tblFinalResult (RowNumber INT, Custid INT, Username VARCHAR(30), TransId BIGINT, OldWinlostDate DATETIME, WinlostDate DATETIME, MemberWinloss MONEY, MemberComm MONEY, MemberTotal MONEY, IsMultipleMoved BIT)

		CREATE TABLE #DataGrid (CustId INT, MemberWinloss MONEY, MemberComm MONEY, MemberTotal MONEY, OldWLD DATETIME, WLD DATETIME)
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

	----get data by conditions
	IF (@custid IS NULL)
	BEGIN
		INSERT INTO #DataDetail(CustId, TransId, OldWinlostDate, WinlostDate, Winlost, ActualStake, PlayerComm, Bettype)
		SELECT sh.CustId, sh.TransId, sh.OldWinlostDate, sh.WinlostDate, sh.Winlost, sh.ActualStake, sh.PlayerComm, sh.Bettype
		FROM dbo.StatementMovementHistory sh WITH(NOLOCK)
			INNER JOIN #Custids c 
				ON c.CustId = sh.CustId
		WHERE 
			EXISTS (SELECT TOP 1 1 FROM #SportBettype b WHERE sh.Bettype = b.Bettype)
			AND 
			(
				(sh.WinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
				OR (sh.OldWinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
			)
			
	END
	ELSE
	BEGIN
		INSERT INTO #DataDetail(CustId, TransId, OldWinlostDate, WinlostDate, Winlost, ActualStake, PlayerComm, Bettype)
		SELECT sh.CustId, sh.TransId, sh.OldWinlostDate, sh.WinlostDate, sh.Winlost, sh.ActualStake, sh.PlayerComm, sh.Bettype
		FROM dbo.StatementMovementHistory sh WITH(NOLOCK)
		WHERE 
			sh.CustId = @custid
			AND EXISTS (SELECT TOP 1 1 FROM #SportBettype b WHERE sh.Bettype = b.Bettype)
			AND 
			(
				(sh.WinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
				OR (sh.OldWinlostDate BETWEEN @InternalFromDate AND @InternalToDate)
			)
			
	END

	----delete parlay, outright have old winlostdate > new winlostdate
	DELETE FROM #DataDetail WHERE Bettype IN (10, 29) AND OldWinlostDate >= WinlostDate

	----paging
	DECLARE @RowStart INT , @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	--@IsVariance
	IF @IsVariance = 0
	BEGIN
		----final result to return to UI
		INSERT INTO #tblFinalResult (RowNumber, Custid, Username, TransId, OldWinlostDate, WinlostDate, MemberWinloss, MemberComm, MemberTotal, IsMultipleMoved)
		SELECT 
			ROW_NUMBER() OVER (ORDER BY c.username, d.TransId, d.OldWinlostDate) AS RowNumber,
			c.Custid, c.Username, d.TransId, d.OldWinlostDate, d.WinlostDate, 
			d.Winlost - d.ActualStake AS MemberWinloss, 
			d.PlayerComm AS MemberComm, 
			d.Winlost - d.ActualStake + d.PlayerComm AS MemberTotal,
			s.IsMultipleMoved
		FROM #DataDetail d WITH(NOLOCK)
			INNER JOIN (
							SELECT CustId,TransId,CASE WHEN COUNT(TransId) > 1 THEN 1 ELSE 0 END AS IsMultipleMoved 
							FROM #DataDetail (NOLOCK)
							GROUP BY CustId,TransId
						) s 
				ON d.CustId = s.CustId AND d.TransId = s.TransId
			INNER JOIN dbo.Customer c WITH(NOLOCK)
				ON c.custid= d.CustId AND c.roleid = 1

		--get total row
		SELECT @TotalRows = COUNT(1) FROM #tblFinalResult fr WITH(NOLOCK)
	
		SELECT
			rs.RowNumber, rs.Custid, rs.Username, rs.TransId, rs.OldWinlostDate, rs.WinlostDate, rs.MemberWinloss, rs.MemberComm, rs.MemberTotal,
			rs.IsMultipleMoved
		FROM #tblFinalResult AS rs
		WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd)
		ORDER BY rs.username, rs.TransId, rs.OldWinlostDate

		-- Data Grid
		INSERT INTO #DataGrid (CustId, MemberWinloss, MemberComm, MemberTotal, OldWLD, WLD)
		SELECT A.Custid, A.MemberWinloss, A.MemberComm, A.MemberTotal, A.OldWinlostDate, A.WinlostDate
		FROM #tblFinalResult A 
		INNER JOIN (
						SELECT 
							rs.Custid,rs.TransId,MAX(rs.WinlostDate) WinlostDate
						FROM #tblFinalResult as rs
						WHERE rs.IsMultipleMoved = 1
						GROUP BY  rs.Custid,rs.TransId
					) B
		ON B.Custid = A.Custid AND B.TransId = A.TransId AND B.WinlostDate = A.WinlostDate
		UNION ALL
		SELECT rs.Custid, rs.MemberWinloss, rs.MemberComm, rs.MemberTotal, rs.OldWinlostDate, rs.WinlostDate  
		FROM #tblFinalResult AS rs
		WHERE IsMultipleMoved = 0

		SELECT d.CustId
				, SUM(MemberWinloss) MemberWinloss
				, SUM(MemberComm) MemberComm
				, SUM(MemberTotal) MemberTotal
				, CASE 
						WHEN @LoggedRoleId = 4 AND c.recommend = -4 THEN 1
						WHEN @LoggedRoleId = 3 AND c.recommend = -3 THEN 1
						ELSE 0 
				END AS IsDirectMember
		FROM #DataGrid d
		INNER JOIN Customer c WITH (NOLOCK) ON d.CustId = c.custid
		GROUP BY d.CustId
				, CASE 
					WHEN @LoggedRoleId = 4 AND c.recommend = -4 THEN 1
					WHEN @LoggedRoleId = 3 AND c.recommend = -3 THEN 1
					ELSE 0 END

		--Data Summary Section
		SELECT 
			COUNT(DISTINCT CustId) TotalMembers,
			SUM(MemberWinloss) MemberWinloss,
			SUM(MemberComm) MemberComm,
			SUM(MemberTotal) MemberTotal,
			SUM(CASE 
					WHEN OldWLD = @InternalToDate AND WLD > @InternalToDate THEN MemberTotal
					ELSE 0 
				END) AS Variance
		FROM #DataGrid
		
	END
	ELSE
	BEGIN
		----final result to return to UI
		INSERT INTO #tblFinalResult (RowNumber, Custid, Username, TransId, OldWinlostDate, WinlostDate, MemberWinloss, MemberComm, MemberTotal, IsMultipleMoved)
		SELECT 
			ROW_NUMBER() OVER (ORDER BY c.username, d.TransId, d.OldWinlostDate) AS RowNumber,
			c.Custid, c.Username, d.TransId, d.OldWinlostDate, d.WinlostDate, 
			d.Winlost - d.ActualStake AS MemberWinloss, 
			d.PlayerComm AS MemberComm, 
			d.Winlost - d.ActualStake + d.PlayerComm AS MemberTotal,
			s.IsMultipleMoved
		FROM #DataDetail d WITH(NOLOCK)
			INNER JOIN (
							SELECT CustId,TransId,CASE WHEN COUNT(TransId) > 1 THEN 1 ELSE 0 END AS IsMultipleMoved 
							FROM #DataDetail (NOLOCK)
							GROUP BY CustId,TransId
						) s 
				ON d.CustId = s.CustId AND d.TransId = s.TransId
			INNER JOIN dbo.Customer c WITH(NOLOCK)
				ON c.custid= d.CustId AND c.roleid = 1
		WHERE d.OldWinlostDate = @InternalToDate									
		AND d.WinlostDate > @InternalToDate									
		
		SELECT @TotalRows = COUNT(1) FROM #tblFinalResult fr WITH(NOLOCK)

		--Detail Variance									
		SELECT									
			rs.RowNumber, rs.Custid, rs.Username, rs.TransId, rs.OldWinlostDate, rs.WinlostDate, rs.MemberWinloss, rs.MemberComm, rs.MemberTotal, rs.IsMultipleMoved								
		FROM #tblFinalResult AS rs									
		WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd)								
		ORDER BY rs.username, rs.TransId, rs.OldWinlostDate
		
		--Data Grid Variance
		INSERT INTO #DataGrid (CustId, MemberWinloss, MemberComm, MemberTotal, OldWLD, WLD)
		SELECT A.Custid, A.MemberWinloss, A.MemberComm, A.MemberTotal, A.OldWinlostDate, A.WinlostDate
		FROM #tblFinalResult A 
		INNER JOIN (
						SELECT 
							rs.Custid,rs.TransId,MAX(rs.WinlostDate) WinlostDate
						FROM #tblFinalResult as rs
						WHERE rs.IsMultipleMoved = 1
						GROUP BY  rs.Custid,rs.TransId
					) B
		ON B.Custid = A.Custid AND B.TransId = A.TransId AND B.WinlostDate = A.WinlostDate
		UNION ALL
		SELECT rs.Custid, rs.MemberWinloss, rs.MemberComm, rs.MemberTotal, rs.OldWinlostDate, rs.WinlostDate  
		FROM #tblFinalResult AS rs
		WHERE IsMultipleMoved = 0

		SELECT c.CustId
			, SUM(MemberWinloss) MemberWinloss
			, SUM(MemberComm) MemberComm
			, SUM(MemberTotal) MemberTotal
			, CASE 
					WHEN @LoggedRoleId = 4 AND c.recommend = -4 THEN 1
					WHEN @LoggedRoleId = 3 AND c.recommend = -3 THEN 1
					ELSE 0 
			END AS IsDirectMember
		FROM #DataGrid d
		INNER JOIN Customer c WITH (NOLOCK) ON d.CustId = c.custid
		GROUP BY c.CustId, CASE 
					WHEN @LoggedRoleId = 4 AND c.recommend = -4 THEN 1
					WHEN @LoggedRoleId = 3 AND c.recommend = -3 THEN 1
					ELSE 0 
			END
	END
	----remove temp tables
	DROP TABLE #SportBettype
	DROP TABLE #DataDetail
	DROP TABLE #Custids
	DROP TABLE #tblFinalResult
	DROP TABLE #DataGrid

END