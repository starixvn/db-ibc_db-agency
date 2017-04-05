/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_PlayForFun_MemberRequest_Detail]
	@CustId INT,
	@ProductId SMALLINT
AS

/*
	Creator: Percy
	Date: 2017-03-20
	DB: DBACC.bodb02
	Task: Select member request - Detail

	Revisions:

	Param's Explanation:
		@CustId: recommend
		@ProductId: productId
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

	DECLARE @IsTest BIT
	SELECT  @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SQL NVARCHAR(MAX)

	CREATE TABLE #member (CustId INT, Username VARCHAR(50), IsSync BIT, Credit MONEY)
	CREATE TABLE #SportBettype (ProductId TINYINT, bettype SMALLINT, RefTable TINYINT)
	CREATE TABLE #netPosition (CustId INT, NetPosition MONEY)

	INSERT INTO #SportBettype (ProductID, bettype, RefTable)
	SELECT ProductID, bettype, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)

	IF @ProductId = 6 -- Casino product
	BEGIN
		INSERT INTO #member (CustId, Username, IsSync, Credit)
		SELECT c.custid, c.username, c.SyncCasino AS IsSync, c.credit
		FROM dbo.custInfo c WITH(NOLOCK)
		WHERE c.recommend = @CustId
			AND c.roleid = 1
			AND (c.DisableCasino = 1 OR c.SyncCasino = 0)
			AND EXISTS (SELECT 1 FROM dbo.CustRequestGame crg WITH(NOLOCK) WHERE crg.CustID = c.custid AND crg.isActive = 1 AND crg.Sporttype = 208)
	END

	SELECT @SQL = N'
		SELECT custid, NetPosition FROM OPENQUERY(DBTXN,
			''SELECT b.custid, SUM(Credit - Debit) AS NetPosition
			  FROM bodb02.dbo.BalNetPosition b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON b.custid = c.custid
			  WHERE c.recommend = ' + CONVERT(NVARCHAR(10), @CustId) + ' AND roleId = 1
			  GROUP BY b.custid
			'')'
	INSERT INTO #netPosition (CustId, NetPosition)
	EXEC (@SQL)

	;WITH Balance AS (
		SELECT b.custid,
			SUM(CASE WHEN ruben = 0 THEN ABS(b.actual_stake) ELSE 0 END) AS OutStanding,
			SUM(CASE WHEN ruben = 1 THEN b.winlost - b.actual_stake + b.playercomm ELSE 0 END) AS Balance
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @CustId
			AND
			(
				b.ruben = 1
				OR
				(
					b.ruben = 0
					AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.RefTable <> 0 AND s.bettype = b.bettype)
				)
			)
			AND
			(
				winlostdate < @yesterday
				OR
				(
					winlostdate >= @yesterday
					AND NOT EXISTS (SELECT 1 FROM #SportBettype s WHERE s.RefTable IN (1, 2) AND s.bettype = b.bettype)
				)
			)
		GROUP BY b.custid

		UNION ALL
		SELECT t.custid,
			SUM(CASE WHEN t.statusID IN (0, 1) THEN ABS(t.actual_stake) ELSE 0 END) AS OutStanding,
			0 AS Balance
		FROM dbo.translog t WITH(NOLOCK)
		WHERE t.recommend = @CustId
			AND EXISTS (
				SELECT 1 FROM #SportBettype s WHERE s.RefTable = 3 AND s.bettype = t.gameID
			)
			AND t.statusID IN (0, 1)
		GROUP BY t.custid

		UNION ALL
		SELECT b.custid,
			SUM(CASE WHEN b.statusID IN (0, 1) THEN ABS(b.actual_stake) ELSE 0 END) AS OutStanding,
			SUM(CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.playercomm ELSE 0 END) AS Balance
		FROM dbo.bettransRnG b WITH(NOLOCK)
		WHERE b.recommend = @CustId
			AND EXISTS (
				SELECT 1 FROM #SportBettype s WHERE s.RefTable = 1 AND s.bettype = b.gameID
			)
			AND
			(
				winlostdate >= @yesterday
				OR
				(
					winlostdate < @yesterday
					AND b.statusID IN (0, 1)
				)
			)
		GROUP BY b.custid

		UNION ALL
		SELECT b.custid,
			SUM(CASE WHEN b.statusID IN (0, 1) THEN ABS(b.actual_stake) ELSE 0 END) AS OutStanding,
			SUM(CASE WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake + b.playercomm ELSE 0 END) AS Balance
		FROM dbo.bettransLC b WITH(NOLOCK)
		WHERE b.recommend = @CustId
			AND EXISTS (
				SELECT 1 FROM #SportBettype s WHERE s.RefTable = 2 AND s.bettype = b.gameID
			)
			AND
			(
				winlostdate >= @yesterday
				OR
				(
					winlostdate < @yesterday
					AND b.statusID IN (0, 1)
				)
			)
		GROUP BY b.custid
	)

	SELECT m.CustId, m.Username, m.IsSync, ISNULL(b.OutStanding, 0) AS OutStanding, ISNULL(b.Balance, 0) AS Balance,
		ISNULL(m.Credit, 0) - ISNULL(b.OutStanding, 0) + ISNULL(b.Balance, 0) + ISNULL(n.NetPosition, 0) AS BetCredit
	FROM #member m
		LEFT JOIN (
			SELECT custid, SUM(OutStanding) AS OutStanding, SUM(Balance) AS Balance
			FROM Balance
			GROUP BY custid
		) b ON m.CustId = b.custid
		LEFT JOIN #netPosition n ON m.CustId = n.CustId

	DROP TABLE #member
	DROP TABLE #SportBettype
	DROP TABLE #netPosition
END
GO