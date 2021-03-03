/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_CustomerSelTotalCash]
	@CustId INT,
	@TotalCash MONEY OUTPUT
AS

/*
	Created by Danny
	Date: 2020-12-22
	DB: DBAGE.bodb02
	Task: Get Total cash of Customer

	Revisions:
		- 20201222@Danny: Get Balance Information of Customer by CustID [RedmineID: #146038]
	
	Param's Explaination:
		- @CustId: custid
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @yesterday SMALLDATETIME, @today SMALLDATETIME
	SELECT @today =   CAST(CURRENT_TIMESTAMP AS DATE)
		, @yesterday = CONVERT(DATE, DATEADD(DAY, -1, @today))

	-- Get bettype --
	DECLARE @isTest BIT = 0
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)
	
	CREATE TABLE #SportBettype (bettype INT, RefTable TINYINT)
	INSERT INTO #SportBettype (bettype, RefTable)
	SELECT bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest)

	DECLARE @roleID TINYINT, @ID INT = 1

	SELECT  @roleID = roleid  FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @custID
	
	IF ISNULL(@roleID, 5) > 4
	BEGIN
		RETURN
	END

	DECLARE @transdate DATETIME, @UsedCredit MONEY, @transid BIGINT
	
		
	-- Get Balance Information 
	DECLARE @tblTotalCash TABLE (TotalCash MONEY)

	CREATE TABLE #recommend (CustId INT)	

    IF @roleid = 1
	BEGIN
	
		-- bettransRNG
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE custid = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN winlost-actual_stake+playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE custid = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettrans
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT
			SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake+playercomm END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.custid = @custid
			AND b.ruben = 1
			AND (
				b.winlostdate < @yesterday
				OR NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
		)

		SELECT @TotalCash = SUM(TotalCash) 
		FROM @tblTotalCash

    END 
    ELSE IF @roleid = 2
    BEGIN

		-- bettransRNG
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END)
	    FROM dbo.bettransRNG WITH(NOLOCK)
		WHERE recommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN awinlost+comm-playercomm ELSE 0 END)
	    FROM dbo.bettransLC WITH(NOLOCK)
		WHERE recommend = @custid
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)
	
		-- bettrans 
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.recommend = @custid
			AND b.ruben = 1
			AND b.winlostdate < @yesterday		
								
		; WITH Bettrans_CTE AS (			
			SELECT	Winlostdate, 
					bettype,
					SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = recommend THEN winlost-actual_stake ELSE awinlost+comm-playercomm END END) AS agentCash
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.recommend = @custid
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday	
			GROUP BY Winlostdate, bettype				
			)			
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(agentCash)
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			
		SELECT @TotalCash = SUM(TotalCash) 
		FROM @tblTotalCash

    END
    ELSE IF @roleid = 3
    BEGIN
	   
		INSERT INTO #recommend (CustId)
		SELECT custid
		FROM CustDB.dbo.custInfo c WITH(NOLOCK)
		WHERE c.roleid = 2 AND mrecommend = @CustId


		-- bettransRNG
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END)
	    FROM  dbo.bettransRNG b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN mwinlost+acomm-comm ELSE 0 END)
	    FROM dbo.bettransLC b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettrans
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE  EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			--AND b.recommend  <> 0     --- level Agent and Customer
			AND b.ruben = 1
			AND b.winlostdate < @yesterday		
			

		; WITH Bettrans_CTE AS (
			SELECT  Winlostdate, 
					bettype,
					SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE mwinlost+acomm-comm END) AS masterCash
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE   
					EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
					--AND b.recommend  <> 0     --- level Agent and Customer
					AND b.ruben = 1
					AND b.winlostdate >= @yesterday		
				GROUP BY Winlostdate, bettype
			)
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT	SUM(masterCash)
		FROM	Bettrans_CTE b
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))
			
			
		-- sum, balance, transfer tickets of this master
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE winlost-actual_stake END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE custid = @custid
			AND b.matchid = 0
			AND b.bettype >= 19999

		SELECT @TotalCash = SUM(TotalCash) 
		FROM @tblTotalCash

		
    END
    ELSE IF @roleid = 4
    BEGIN    	

		INSERT INTO #recommend (CustId)
		SELECT custid
		FROM CustDB.dbo.custInfo c WITH(NOLOCK)
		WHERE c.roleid = 2 AND srecommend = @CustId
		
		-- bettransRNG
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT  SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END)
	    FROM dbo.bettransRNG b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettransLC
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN statusID NOT IN (0,1) THEN swinlost+scomm-acomm ELSE 0 END)
	    FROM dbo.bettransLC b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			AND (
				statusID IN (0,1)
				OR winlostdate >= @yesterday
			)

		-- bettrans 
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE swinlost+scomm-acomm END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE 
			EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
			--AND b.recommend <> 0     --- level Agent and Customer
			AND b.ruben = 1
			AND b.winlostdate < @yesterday

		;WITH Bettrans_CTE AS (
			SELECT winlostdate, Bettype,
					SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE swinlost+scomm-acomm END) superCash
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE 
				EXISTS (SELECT 1 FROM #recommend r WHERE b.recommend = r.CustId)
				--AND b.recommend <> 0     --- level Agent and Customer
				AND b.ruben = 1
				AND b.winlostdate >= @yesterday
			GROUP BY winlostdate, Bettype 
		 )
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(superCash)
		FROM Bettrans_CTE b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SportBettype s WHERE s.Bettype = b.bettype AND s.RefTable IN (1, 2))


			-- sum, balance, transfer tickets of this super and all masters
		INSERT INTO @tblTotalCash (TotalCash)
		SELECT SUM(CASE WHEN b.bettype IN (21008, 21009) THEN 0 ELSE CASE WHEN custid = srecommend THEN winlost-actual_stake ELSE swinlost+scomm-acomm END END)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE 
			b.srecommend = @CustID
			AND (b.recommend * @ID) = 0   --- level master and super 
			AND b.matchid = 0
			AND b.bettype >= 19999

		SELECT @TotalCash = SUM(TotalCash)
		FROM @tblTotalCash

    END
	DROP TABLE #recommend
	DROP TABLE #SportBettype
END
