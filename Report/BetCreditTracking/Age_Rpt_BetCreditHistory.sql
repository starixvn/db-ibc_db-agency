/*<info serverAlias="DBBAH-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Age_Rpt_BetCreditHistory
(
	@FromDate DATETIME,
	@Todate DATETIME,
	@UserName VARCHAR(30) = '',
	@RefNo BIGINT = NULL,
	@LoggedId INT = -1,
	@PageIndex INT = 1,
	@PageSize INT = 50,
	@TotalRows INT = 0 OUTPUT,
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
		- 20220707@Sol: Alpha - Hide sum row (isSum 1 to 0) - [RedmineID: #173971] 
		- 20230531@Danny: Remove some filter conditions [RedmineID: #188355] 
		- 20230621@Lewis: Hide 19, 35 & Get data WLDate&Refno from BalanceRecord [RedmineID: #189598] 
		- 20231109@Sophia: Hide last data of SpecialCustomer [Redmine: #196719]
*/
BEGIN

	DECLARE 
		@MoveBetsDay	SMALLDATETIME, 
		@BalanceUpDay	SMALLDATETIME,
		@InternalFromDate DATETIME,
		@InternalToDate DATETIME,
		@CustId INT = 0,
		@IsEnabled BIT = 0,
		@LoggedRoleId TINYINT,
		@OldCreditFirstTimes MONEY,
		@OldActionDateFirstTimes DATETIME
		

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	SELECT @LoggedRoleId = c.roleid
	FROM dbo.Customer c WITH(NOLOCK)
	WHERE c.custid = @LoggedId

	----validate user
	BEGIN
		SELECT @CustId = custId
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.username = @UserName

		--member not exist
		IF (@CustId IS NULL OR @CustId = 0)
		BEGIN
			SELECT @ErrorCode = 101, @ErrorMess = 'Invalid member'
			RETURN
		END

		SELECT @IsEnabled = c.Enabled
		FROM dbo.custInfo c WITH(NOLOCK)
		WHERE c.custid	 = @CustId

		--member is disabled
		IF (@IsEnabled = 0)
		BEGIN
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
			SELECT @ErrorCode = 101, @ErrorMess = 'Invalid member'
			RETURN
		END

	END
	----end validation

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay FROM @tmp
	SELECT @InternalFromDate = @FromDate, @InternalToDate = DATEADD(DAY, 1, @Todate) --cover for users that are created in @today

	----check BU date with from/to date
	IF (@FromDate < @BalanceUpDay OR @Todate < @BalanceUpDay)
	BEGIN
		SELECT @ErrorCode = 102, @ErrorMess = 'From Date/To Date must be greater than or equal "' + CONVERT(VARCHAR(20), @BalanceUpDay, 101) + '"'
		RETURN
	END

	CREATE TABLE #BalanceRecord(ActionDate DATETIME, winlostdate SMALLDATETIME, refNo BIGINT, actual_stake MONEY, winloss MONEY, playercomm MONEY, BalanceChanged MONEY, NewBalance MONEY, GivenCredit MONEY, BetCredit MONEY, Action VARCHAR(256), custid INT, ActionID INT, rowid BIGINT, bettype SMALLINT, IsUserLogActionId BIT)
	CREATE TABLE #LogCredit(ActionID INT, ActionNameEN NVARCHAR(256), logid BIGINT, custid INT, logdate DATETIME, OldValue MONEY, NewValue MONEY)

	IF EXISTS (SELECT top 1 1 from dbo.Customer c WITH(NOLOCK) WHERE c.creatdate > @InternalToDate AND c.custid = @CustId AND c.roleid = 1)
	BEGIN

		SELECT 
			t.ActionDate, t.winlostdate, t.refNo, t.actual_stake, t.winloss, t.playercomm, t.BalanceChanged, t.NewBalance, t.GivenCredit, t.BetCredit, t.Action
		FROM #BalanceRecord t

	END
	ELSE
	BEGIN

		--- get infor from userlog_credit
		INSERT INTO #LogCredit(ActionID, ActionNameEN, logid, custid, logdate, OldValue, NewValue)
		SELECT u.ActionID, l.ActionNameEN, u.logid, u.custid, u.logdate, u.OldValue, u.NewValue 
		FROM DBLog.bodb_CustomerLog.dbo.UserLog_Credit u WITH(NOLOCK)
			INNER JOIN DBLog.bodb_CustomerLog.dbo.LogAction l WITH(NOLOCK)
				ON u.ActionID = l.ActionID
		WHERE 
			u.custid = @CustId
			AND u.logdate >= @InternalFromDate

		IF NOT EXISTS (SELECT TOP 1 1 FROM #LogCredit)
		BEGIN
			SELECT @OldCreditFirstTimes = c.credit, @OldActionDateFirstTimes = @InternalFromDate
			FROM dbo.custInfo c WITH(NOLOCK) 
			WHERE c.custid = @CustId AND c.roleid = 1
		END
		ELSE 
		BEGIN
			SELECT TOP 1 
				@OldCreditFirstTimes = ISNULL(l.OldValue, l.newvalue), 
				@OldActionDateFirstTimes = CASE WHEN l.OldValue IS NULL THEN l.logdate ELSE @InternalFromDate END
			FROM #LogCredit l
			ORDER BY logdate
		END

		--- insert to temp table balance record
		;WITH rs AS
		(
			SELECT 
				ActionDate, 
				b.winlostdate, 
				CASE WHEN sbm.RefTable = 3 AND b.refno IS NOT NULL THEN b.refno ELSE b.transid END AS refNo, 
				b.actual_stake, 
				b.winlost,
				b.playercomm, 
				b.BalanceChanged, 
				b.NewBalance,
				b.Action, 
				b.custid, b.ActionID, b.RowID,
				b.bettype
			FROM dbo.BalanceRecord b WITH(NOLOCK)
				LEFT JOIN SportBettypeMatrix sbm WITH(NOLOCK)
					ON b.bettype = sbm.BetType AND sbm.RefTable = 3
			WHERE 
				b.custid = @CustId
				AND b.ActionDate >= @InternalFromDate 
				AND b.ActionDate < @InternalToDate
				AND b.Actionid NOT IN (33, 19, 35) --- excluded action change of IsSum from 0 to 1, betupdated, translogsettled
				AND 1 = CASE 
							WHEN b.BalanceChanged = 0 AND b.ActionID = 31 AND Action LIKE '%IsSUM : 1 to 0%' THEN 0
							WHEN b.BalanceChanged = 0 AND b.ActionID IN (0, 1, 20, 21, 100, 255) THEN 0 --excluded others (won/lose->won/lose...), Reject Bet, Accept Bet, Bet SUM insert, Balance insert
							ELSE 1
						END
			UNION
			SELECT 
				ActionDate, 
				b.winlostdate, 
				CASE WHEN sbm.RefTable = 3 AND b.refno IS NOT NULL THEN b.refno ELSE b.transid END AS refNo, 
				b.actual_stake, 
				b.winlost,
				b.playercomm, 
				b.BalanceChanged, 
				b.NewBalance,
				b.Action, 
				b.custid, b.ActionID, b.RowID,
				b.bettype
			FROM BalanceRecord.dbo.BalanceRecord_bk b WITH(NOLOCK)
				LEFT JOIN SportBettypeMatrix sbm WITH(NOLOCK)
					ON b.bettype = sbm.BetType AND sbm.RefTable = 3
			WHERE 
				b.custid = @CustId
				AND b.ActionDate >= @InternalFromDate 
				AND b.ActionDate < @InternalToDate
				AND b.Actionid NOT IN (33, 19, 35) --- excluded action change of IsSum from 0 to 1, betupdated, translogsettled
				AND 1 = CASE 
							WHEN b.BalanceChanged = 0 AND b.ActionID = 31 AND Action LIKE '%IsSUM : 1 to 0%' THEN 0
							WHEN b.BalanceChanged = 0 AND b.ActionID IN (0, 1, 20, 21, 100, 255) THEN 0 --excluded others (won/lose->won/lose...), Reject Bet, Accept Bet, Bet SUM insert, Balance insert
							ELSE 1
						END
		)
		INSERT INTO #BalanceRecord(ActionDate, winlostdate, refNo, actual_stake, winloss, playercomm, BalanceChanged, NewBalance, GivenCredit, BetCredit, Action, custid, ActionID, rowid, rs.bettype, IsUserLogActionId)
		SELECT 
			COALESCE(ActionDate, l.logdate) ActionDate, 
			b.winlostdate, 
			b.refNo, 
			b.actual_stake, 
			b.winlost,
			b.playercomm, 
			b.BalanceChanged, 
			b.NewBalance,
			COALESCE(l.NewValue, lo.NewValue, @OldCreditFirstTimes, 0) GivenCredit,
			(b.NewBalance + COALESCE(l.NewValue, lo.NewValue, @OldCreditFirstTimes, 0)) AS BetCredit,
			COALESCE(Action, l.ActionNameEN) AS Action, 
			COALESCE(b.custid, l.custid) AS custid, COALESCE(b.ActionID, l.ActionID), b.RowID, b.bettype,
			CASE WHEN b.ActionID IS NULL AND l.ActionID IS NOT NULL THEN 1 ELSE 0 END
		FROM rs b WITH(NOLOCK)
			FULL JOIN 
			(
				SELECT ActionID, ActionNameEN, logid, custid, logdate, OldValue, NewValue 
				FROM #LogCredit l 
			) l ON l.logdate = b.ActionDate AND l.ActionID = b.ActionID AND l.custid = b.custid
			OUTER APPLY 
			(
				SELECT TOP 1 ActionID, ActionNameEN, logid, custid, logdate, OldValue, NewValue 
				FROM #LogCredit lo
				WHERE lo.logdate < b.ActionDate AND lo.custid = b.custid
				ORDER BY lo.logdate DESC
			) lo 
		
		DELETE b		
		FROM #BalanceRecord b	 
		INNER JOIN SpecialCustomer s WITH (NOLOCK) 
			ON b.CustID = s.CustID AND b.ActionDate < '2023-11-09' 

		--###############################################################


		DECLARE @RowStart INT , @RowEnd INT
		SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1
		
		BEGIN
			---filter by refno only again because need to given credit to cal bet credit until now
			IF (@RefNo IS NOT NULL)
			BEGIN
				SELECT @TotalRows = COUNT(1) 
				FROM #BalanceRecord b WITH(NOLOCK) 
				WHERE b.refNo = @RefNo 
					
				;WITH rs AS
				(
					SELECT 
						ROW_NUMBER() OVER (ORDER BY ActionDate, rowid) AS RowNumber,
						b.ActionID,
						b.ActionDate, 
						b.Winlostdate, 
						b.RefNo, 
						b.Actual_stake,
						b.Winloss,
						b.Playercomm, 
						b.BalanceChanged, 
						b.NewBalance,
						b.GivenCredit,
						b.BetCredit,
						b.Action,
						b.rowid,
						b.IsUserLogActionId
					FROM #BalanceRecord b
					WHERE b.refNo = @RefNo
				)
				SELECT * FROM rs
				WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd)					 
				ORDER BY ActionDate, rowid
					
			END
			ELSE
			BEGIN
				SELECT @TotalRows = COUNT(1) 
				FROM #BalanceRecord b WITH(NOLOCK)

				SET @TotalRows = @TotalRows + 1

				;WITH rs
				AS
				(
					SELECT 
						ROW_NUMBER() OVER (ORDER BY ActionDate, rowid) AS RowNumber,
						t.ActionId, t.ActionDate, t.Winlostdate, t.RefNo, t.Actual_stake, t.Winloss, t.Playercomm, t.BalanceChanged, t.NewBalance, t.GivenCredit, t.BetCredit, t.Action, t.Rowid, t.IsUserLogActionId
					FROM 
					(
						SELECT 
							-1 AS ActionId,
							@OldActionDateFirstTimes ActionDate,
							NULL AS winlostdate, 
							NULL AS refNo, 
							NULL AS actual_stake, 
							NULL AS winloss, 
							NULL AS playercomm, 
							NULL AS BalanceChanged, 
							NULL AS NewBalance, 
							@OldCreditFirstTimes AS GivenCredit, 
							NULL AS BetCredit, 
							'Opening Credit' AS Action,
							NULL AS rowid,
							0 AS IsUserLogActionId
						UNION
						SELECT 
							b.ActionID,
							b.ActionDate, 
							b.winlostdate, 
							b.refNo, 
							b.actual_stake,
							b.winloss,
							b.playercomm, 
							b.BalanceChanged, 
							b.NewBalance,
							b.GivenCredit,
							b.BetCredit,
							b.Action,
							b.rowid,
							b.IsUserLogActionId
						FROM #BalanceRecord b
					) t
				)
				SELECT * FROM rs
				WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd)
				ORDER BY ActionDate, rowid
			END
		END

	END

	DROP TABLE #BalanceRecord
	DROP TABLE #LogCredit

END