
ALTER PROCEDURE [dbo].[Age_Rpt_WinLossDetail_Ag_ByUserName] 
	@CustID int = NULL,--recommend
	@FromDate smalldatetime,
	@ToDate smalldatetime,
	@showSB bit=1,
	@showCasino bit=0,
	@showP2P bit=0,
	@ShowRB bit=0,
	@showFI bit=0,
	@BalanceUpDay SMALLDATETIME,
	@UserName varchar(30) = null,
	@ErrCode INT = 0 OUTPUT 

AS
/*
Created: 
Task : Member Winloss Detail By UserName
DB: DB05.bodb02
Original Age_Rpt_WinLossDetail_Ag_ByUserName
Revisions:
    - 20100310@Terry: Create sps Report Winloss Detail search by username
	- 20110308@Lukas: change @showHR -> @showRB
	- 20120405@Hurri: Change bettype of P2P (72 -> 1000)
Param's Explanation: 
	- @CustID : recommend 
	- @Username: member's username 

*/
SET NOCOUNT ON

DECLARE @Mem_CustID int

IF NOT exists(SELECT 1 FROM CustInfo with(nolock) WHERE UserName = @UserName AND Recommend=@CustID AND RoleID=1) 
BEGIN
	SELECT @ErrCode = 100 RETURN 
END
ELSE 
BEGIN
	SELECT	@Mem_CustID = custid FROM Custinfo with(nolock) WHERE UserName = @UserName AND Recommend=@CustID AND RoleID=1

	DECLARE @MemWinLossDetails TABLE(
		TurnOver money, GrossComm money, MemberWinLost money, 
		PlayerComm money, MemberTotal money, AgWinLost money, AgComm money, AgTotal money, Company money)
	DECLARE @TmpCond TABLE(sporttype INT, bettype INT)
	DECLARE @TmpCondSumWL TABLE(sporttype INT, bettype INT)
	IF @ShowSB = 1
	BEGIN
		--Bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)
		SELECT 0 AS sporttype, typeid FROM bettype (NOLOCK)
		WHERE typeid < 99 AND typeid NOT IN (71,1000,31,32,33,41,42,43,51,52,53,54,55,56,61,62,63,64,65,66)	--20120405@Hurri
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)
		VALUES(0,0)	
	END
	IF @ShowCasino = 1
	BEGIN
		INSERT INTO @TmpCond(sporttype, Bettype)
		VALUES(251,71)
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)
		VALUES(251,71)
	END
	IF @ShowP2P = 1
	BEGIN
		INSERT INTO @TmpCond(sporttype, Bettype)
		VALUES(251,1000)	--20120405@Hurri
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(sporttype, Bettype)
		VALUES(251,1000)	--20120405@Hurri
	END
	IF @ShowRB = 1
	BEGIN
		--Bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)
		SELECT 151 AS sporttype, typeid FROM bettype (NOLOCK)
		WHERE typeid IN (31,32,33,41,42,43)
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
		VALUES(151,0)
	END
	IF @ShowFI = 1
	BEGIN	
		--Bettrans
		INSERT INTO @TmpCond(Sporttype, Bettype)
		SELECT 201 AS sporttype, typeid FROM bettype (NOLOCK)
		WHERE typeid IN (51,52,53,54,55,56,61,62,63,64,65,66)
		--Sum_winloss
		INSERT INTO @TmpCondSumWL(Sporttype, Bettype)
		VALUES(201,0)
	END

	IF @Todate >= @BalanceUpDay
	BEGIN 
		INSERT INTO @MemWinLossDetails
			SELECT		    
				SUM(case when b.liveawayscore = 0 and b.bettype in(33,43) then b.stake/2 else b.stake end),	
				sum(comm/(1- apositiontaking)) as GrossComm,
				sum(winlost-actual_stake), --MemberWinlost
				sum(playercomm), -- PlayerComm
				isnull(sum(winlost-actual_stake), 0) + isnull(sum(playercomm), 0), --MemberTotal
				sum(awinlost), -- AgWinlost
				sum(comm-playercomm), --AgComm
				isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
				-isnull(sum(winlost-actual_stake +awinlost+comm), 0) --Company
			FROM
				dbo.bettrans b WITH (NOLOCK) INNER JOIN @TmpCond t ON b.bettype = t.bettype
			WHERE
				winlostdate between @FromDate and @todate
				and status not in ('VOID', 'REJECT', 'Refund')
				and Recommend=@CustID
				and Custid = @Mem_CustID
				and ruben=1 
			GROUP BY b.bettype

		if @BalanceUpDay < @FromDate
			select @BalanceUpDay=@FromDate
			
		INSERT INTO @MemWinLossDetails
			SELECT		  		
				sum(TurnOver), -- TurnOver
				sum(grosscomm) as GrossComm,
				sum(winlost), --MemberWinlost
				sum(playercomm), -- PlayerComm
				isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
				sum(awinlost), -- AgWinlost
				sum(comm-playercomm), --AgComm
				isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
				-isnull(sum(winlost+awinlost+comm), 0) --Company
			FROM
				dbo.sum_winloss b WITH (NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
			WHERE
				winlostdate between @BalanceUpDay and @todate			
				and recommend=@CustID
				and Custid = @Mem_CustID
				and RoleID=1	    
	END

	IF @FromDate < @BalanceUpDay 
	BEGIN
		if @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			select @ToDate = DATEADD(dd, -1, @BalanceUpDay)
		
		INSERT INTO @MemWinLossDetails
			SELECT   	
				sum(TurnOver), -- TurnOver
				sum(grosscomm) as GrossComm,
				sum(winlost), --MemberWinlost
				sum(playercomm), -- PlayerComm
				isnull(sum(winlost), 0) + isnull(sum(playercomm), 0), --MemberTotal
				sum(awinlost), -- AgWinlost
				sum(comm-playercomm), --AgComm
				isnull(sum(awinlost), 0) + isnull(sum(comm-playercomm), 0), --AgTotal
				-isnull(sum(winlost+awinlost+comm), 0) --Company
			FROM
				bodb_Summary.dbo.Sum_WinLoss_Old b WITH(NOLOCK) INNER JOIN @TmpCondSumWL t ON b.sporttype = t.sporttype AND b.bettype = t.bettype
			WHERE
				winlostdate between @fromdate and @ToDate	
				and recommend=@custid
				and Custid = @Mem_CustID
				and RoleID=1
	END

	SELECT
			@Mem_CustID CustID, 
			@Username UserName, 
			sum(TurnOver) as TurnOver,
			sum(GrossComm) as GrossComm,
			sum(MemberWinLost) as MemberWinlost,
			sum(PlayerComm) as PlayerComm,
			sum(MemberTotal) as MemberTotal,
			sum(AgWinlost) as AgWinlost,
			sum(AgComm) as AgComm,
			sum(AgTotal) as AgTotal,
			sum(Company) as Company,
			1 as RowNum	
	FROM	@MemWinLossDetails 
END 


GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_ByUserName] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_WinLossDetail_Ag_ByUserName] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_WinLossDetail_Ag_ByUserName] TO [vnteam]
