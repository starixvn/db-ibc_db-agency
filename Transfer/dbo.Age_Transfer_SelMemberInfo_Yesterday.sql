/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_SelMemberInfo_Yesterday]
	@custid int,--member 
	@IsAllowTotalBalance bit = null,
	@username varchar(20) OUTPUT,--member 
	@syncCasino BIT = 0 OUTPUT ,
	@DisableCasino BIT = 0 OUTPUT,
	@CashBalance money OUTPUT,
	@Oustanding money OUTPUT,
	@GivenCredit money OUTPUT,
	@BetCredit money OUTPUT,
	@LastLogin datetime OUTPUT,
	@Balance money OUTPUT,
	@MaxTransDate datetime OUTPUT,
	@FutureBetCredit money OUTPUT,
	@AmtTransferred money = 0 OUTPUT
AS
/*
Created: ???
Task : 
DB: DBTXN.bodb02
Original: Age_Transfer_SelMemberInfo_Yesterday_1
	Revisions:
		- 20090505@Phuc: get amount transferred.
		- 20100105@Jamie: Remove exchange table out and @currency param 
		- 20101224@Johnson: Apply new arrange of bettype
		- 20110111@henry: add one more output @FutureBetCredit to show negative bet credit that may happen after the transfer
		- 20110123@Thien: fix the FutureBetCredit formula
		- 20111108@Lukas: Get more column syncCasino
		- 20120403@Lukas: Get more column DisableCasino
		- 20160127@Percy: Balance changes with RNG Casino [Redmine: #50674]
		- 20160321@Percy: Support AllBet [Redmine: #50605]
		- 20160413@Percy: Support Voidbridge single wallet [Redmine: #55259]
		- 20161028@Percy: Support Fishing World [RedmineID: #65731]
		- 20180521@Percy: Add waiting tickets on translog [RedmineID: #95268]
		- 20181005@Percy: Remove convert date on winlostdate [RedmineID: #101644]
		- 20190305@Helen: Move SP to DBTRANS - Enhance Transfer function to avoid replication delay [RedmineID : #107963]
*/
SET NOCOUNT ON

DECLARE @isTest BIT
SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID)

CREATE TABLE #SportBettype (ProductID INT, bettype INT, RefTable TINYINT)
INSERT INTO #SportBettype (ProductID, bettype, RefTable)
SELECT ProductID, bettype, RefTable FROM dbo.f_SportBettypeMatrix_Sel(0,0,0,2,'','',@isTest)

DECLARE @today DATE,
		@yesterday DATE
SELECT  @today = CONVERT(DATE, GETDATE())
SELECT  @yesterday = DATEADD(DD, -1, @today)

SELECT  @IsAllowTotalBalance = isnull(@IsAllowTotalBalance, 0)

DECLARE @RoleID INT --nqminh - 19Feb09

IF (@IsAllowTotalBalance = 0)
    select   
	     @RoleID = customer.roleid, --nqminh - 19Feb09
	     @LastLogin = customer.lastlogged,
	     @Username = customer.username,  
		 @syncCasino = ci.syncCasino,
		 @DisableCasino = ci.DisableCasino,
	     @GivenCredit = ci.credit,
	     @CashBalance = isnull(b.CashBalance,0)
    from CUSTDB.dbo.customer with (NOLOCK)  
	    INNER JOIN CUSTDB.dbo.CustInfo as ci with (NOLOCK) on Customer.CustID = ci.CustID  
	    LEFT JOIN 
		    (	
				SELECT custid, SUM(CashBalance) AS CashBalance
				FROM (
						SELECT custid, isnull(sum( case when b.bettype < 19001 and b.winlostdate < @today then b.winlost-b.actual_stake+playercomm
														when b.bettype > 19000 then b.winlost-b.actual_stake +playercomm
														else 0 end ), 0) as CashBalance 
						FROM bettrans as b with (NOLOCK) 
						WHERE custid = @CustID and ruben  =1
							AND (
									(winlostdate >= @yesterday
										AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable NOT IN (0,3))
									)
									OR winlostdate < @yesterday
								)
						GROUP BY custid
						UNION ALL
						SELECT custid, isnull(sum(b.winlost-b.actual_stake+playercomm), 0) as CashBalance 
						FROM bettransRNG as b with (NOLOCK) 
						WHERE custid = @CustID and statusID NOT IN (0, 1)
							--AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
							AND winlostdate = @yesterday
						GROUP BY custid
						UNION ALL
						SELECT custid, isnull(sum(b.winlost-b.actual_stake+playercomm), 0) as CashBalance 
						FROM bettransLC as b with (NOLOCK) 
						WHERE custid = @CustID and statusID NOT IN (0, 1)
							--AND gameID BETWEEN 2401 AND 2499
							AND winlostdate = @yesterday
						GROUP BY custid
					  ) AS A
				GROUP BY custid
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @CustID  
ELSE
    select   
	     @RoleID = customer.roleid, --nqminh - 19Feb09
	     @LastLogin = customer.lastlogged,
	     @Username = customer.username, 
		 @syncCasino = ci.syncCasino, 
		 @DisableCasino = ci.DisableCasino,
	     @GivenCredit = ci.credit,
	     @CashBalance = isnull(b.CashBalance,0)
    from CUSTDB.dbo.customer with (NOLOCK)  
	    INNER JOIN CUSTDB.dbo.CustInfo as ci with (NOLOCK) on Customer.CustID = ci.CustID  
	    LEFT JOIN 
		    (   SELECT custid, SUM(CashBalance) AS CashBalance
				FROM (
						SELECT custid, isnull(sum(b.winlost-b.actual_stake+playercomm), 0) as CashBalance 
						FROM bettrans as b with (NOLOCK) 
						WHERE custid = @CustID and ruben  =1
							AND (
									(winlostdate >= @yesterday
										AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable NOT IN (0,3))
									)
									OR winlostdate < @yesterday
								)
						GROUP BY custid
						UNION ALL
						SELECT custid, isnull(sum(b.winlost-b.actual_stake+playercomm), 0) as CashBalance 
						FROM bettransRNG as b with (NOLOCK) 
						WHERE custid = @CustID and statusID NOT IN (0, 1)
							--AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
							AND winlostdate >= @yesterday
						GROUP BY custid
						UNION ALL
						SELECT custid, isnull(sum(b.winlost-b.actual_stake+playercomm), 0) as CashBalance 
						FROM bettransLC as b with (NOLOCK) 
						WHERE custid = @CustID and statusID NOT IN (0, 1)
							--AND gameID BETWEEN 2401 AND 2499
							AND winlostdate >= @yesterday
						GROUP BY custid
					) AS A
				GROUP BY custid
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @CustID  

select @BetCredit = @GivenCredit + @CashBalance

SELECT @Oustanding = ISNULL(SUM(actual_stake), 0) FROM bettrans WITH (NOLOCK)
WHERE bettype < 19001
	AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable <> 0)
	AND ruben = 0
	AND custid = @custid

SELECT @Oustanding = @Oustanding + ISNULL(SUM(actual_stake), 0) FROM bettransRNG WITH (NOLOCK)
WHERE /*(GameID BETWEEN 2101 AND 2399 OR GameID BETWEEN 4001 AND 7999)
	AND */ StatusID IN (0,1)
	AND custid = @custid

SELECT @Oustanding = @Oustanding + ISNULL(SUM(actual_stake), 0) FROM bettransLC WITH (NOLOCK)
WHERE /*GameID BETWEEN 2401 AND 2499
	AND */ StatusID IN (0,1)
	AND custid = @custid

SELECT @Oustanding = @Oustanding + ISNULL(SUM(actual_stake), 0) FROM translog WITH (NOLOCK)
WHERE custid = @custid
	AND statusID IN (0, 1)

--Start - nqminh - 19Feb09	
IF (@RoleId = 1)
BEGIN
	DECLARE @TotalCash money
	SELECT  @TotalCash      = ISNULL(SUM(winlost-actual_stake+playercomm), 0),
		    @AmtTransferred = ISNULL(SUM(case when winlostdate = @today AND bettype = 21004 then winlost - actual_stake else 0 end), 0)
	FROM bettrans WITH (NOLOCK)
	WHERE custid = @CustID
		AND ruben = 1
		AND (
				(winlostdate >= @yesterday
					AND bettype NOT IN (SELECT bettype FROM #SportBettype WHERE RefTable NOT IN (0,3))
				)
				OR winlostdate < @yesterday
			)

	SELECT  @TotalCash      = @TotalCash + ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM bettransRNG WITH (NOLOCK)
	WHERE custid = @CustID
		AND statusID NOT IN (0, 1)
		--AND (gameID BETWEEN 2101 AND 2399 OR gameID BETWEEN 4001 AND 7999)
		AND winlostdate >= @yesterday

	SELECT  @TotalCash      = @TotalCash + ISNULL(SUM(winlost-actual_stake+playercomm), 0)
	FROM bettransLC WITH (NOLOCK)
	WHERE custid = @CustID
		AND statusID NOT IN (0, 1)
		--AND gameID BETWEEN 2401 AND 2499
		AND winlostdate >= @yesterday


	SELECT @BetCredit = @GivenCredit + @TotalCash - @Oustanding
END
--End - nqminh - 19Feb09	

select @Balance = @CashBalance

select @MaxTransDate = MAX(transdate) FROM bettrans WITH (NOLOCK) WHERE custid=@custid

if @CashBalance > 0 
	set @FutureBetCredit = @GivenCredit - @Oustanding + @TotalCash - @CashBalance
else
	set @FutureBetCredit = 0

DROP TABLE #SportBettype


GO