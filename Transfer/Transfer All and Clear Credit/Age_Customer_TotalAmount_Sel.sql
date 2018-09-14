/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Customer_TotalAmount_Sel]
	@CustId INT,
	@RoleId TINYINT
AS

/*
	Created: 20180801@Percy
	DB: DBTXN.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Clear Credit - Get Member's Amount

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME
	SELECT  @yesterday = DATEADD(DAY, -1, CONVERT(DATE, GETDATE()))

	CREATE TABLE #tempData
	(
		winlostdate SMALLDATETIME, bettype INT, statusId TINYINT,
		custid INT, amount MONEY
	)

	IF @RoleId = 3
	BEGIN
		DECLARE @tblrecommend TABLE (recommend INT PRIMARY KEY)
		INSERT INTO @tblrecommend (recommend)
		SELECT custid FROM CustDB.dbo.custInfo WITH (NOLOCK) WHERE mrecommend = @custId AND roleId = 2

		-- bettrans
		INSERT INTO #tempData
		(
			winlostdate, bettype, statusId,
			custid, amount
		)
		SELECT
			b.winlostdate, b.bettype, b.statusId,
			b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @tblrecommend r ON b.recommend = r.recommend
		GROUP BY
			b.winlostdate, b.bettype, b.statusId,
			b.custid

		DELETE t
		FROM #tempData t
		WHERE EXISTS (
			SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE t.bettype = s.bettype AND s.RefTable IN (1,2)
		)
			AND t.winlostdate >= @yesterday

		DELETE t
		FROM #tempData t
		WHERE EXISTS (
			SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE t.bettype = s.bettype AND s.RefTable IN (3)
		)
			AND t.statusId IN (0,1)

		-- bettransRnG
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettransRnG b WITH (NOLOCK)
			INNER JOIN @tblrecommend r ON b.recommend = r.recommend
		WHERE (b.statusId IN (0,1) OR b.winlostdate >= @yesterday)
		GROUP BY b.custid

		-- bettransLC
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettransLC b WITH (NOLOCK)
			INNER JOIN @tblrecommend r ON b.recommend = r.recommend
		WHERE (b.statusId IN (0,1) OR b.winlostdate >= @yesterday)
		GROUP BY b.custid

		-- translog
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT t.custid, SUM(-t.actual_stake)
		FROM dbo.translog t WITH (NOLOCK)
			INNER JOIN @tblrecommend r ON t.recommend = r.recommend
		WHERE t.statusId IN (0,1)
		GROUP BY t.custid

		-- netPostion
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT np.custid, SUM(ISNULL(np.credit, 0) - ISNULL(np.debit, 0))
		FROM dbo.BalNetPosition np WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON np.CustID = c.custid
		WHERE c.mrecommend = @CustId AND c.roleId = 1
		GROUP BY np.custid
	END
	ELSE IF @RoleId = 2
	BEGIN
		-- bettrans
		INSERT INTO #tempData
		(
			winlostdate, bettype, statusId,
			custid, amount
		)
		SELECT
			b.winlostdate, b.bettype, b.statusId,
			b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettrans b WITH (NOLOCK)
		WHERE b.recommend = @CustId
		GROUP BY
			b.winlostdate, b.bettype, b.statusId,
			b.custid

		DELETE t
		FROM #tempData t
		WHERE EXISTS (
			SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE t.bettype = s.bettype AND s.RefTable IN (1,2)
		)
			AND t.winlostdate >= @yesterday

		DELETE t
		FROM #tempData t
		WHERE EXISTS (
			SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			WHERE t.bettype = s.bettype AND s.RefTable IN (3)
		)
			AND t.statusId IN (0,1)

		-- bettransRnG
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettransRnG b WITH (NOLOCK)
		WHERE b.recommend = @CustId
			AND (b.statusId IN (0,1) OR b.winlostdate >= @yesterday)
		GROUP BY b.custid

		-- bettransLC
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM dbo.bettransLC b WITH (NOLOCK)
		WHERE b.recommend = @CustId
			AND (b.statusId IN (0,1) OR b.winlostdate >= @yesterday)
		GROUP BY b.custid

		-- translog
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT t.custid, SUM(-t.actual_stake)
		FROM dbo.translog t WITH (NOLOCK)
		WHERE t.recommend = @CustId
			AND t.statusId IN (0,1)
		GROUP BY t.custid

		-- netPostion
		INSERT INTO #tempData
		(
			custid, amount
		)
		SELECT np.custid, SUM(ISNULL(np.credit, 0) - ISNULL(np.debit, 0))
		FROM dbo.BalNetPosition np WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON np.CustID = c.custid
		WHERE c.recommend = @CustId AND c.roleId = 1
		GROUP BY np.custid
	END

	SELECT custid, SUM(amount) AS amount
	FROM #tempData
	GROUP BY custid
	HAVING SUM(amount) <> 0

	DROP TABLE #tempData
END