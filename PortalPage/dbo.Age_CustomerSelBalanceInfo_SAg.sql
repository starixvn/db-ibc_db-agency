
ALTER PROCEDURE [dbo].[Age_CustomerSelBalanceInfo_SAg]
	 @custid		INT
	 ,@MoveBetsDay	DATETIME
AS
/*
	Created: Johnson
	Date: 2011-04-27
	DB: DB052.BODB02
	Task: Get Super Balance Info 
	
	Revisions:
		- 20110803@Johnson: Include commission into today winloss and yesterday winloss
		- 20150318@Cody: Apply sporttype bettype matrix
*/
SET NOCOUNT ON 

DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
		
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

DECLARE @username			NVARCHAR(50)
		,@roleid			INT
		,@givenCredit		MONEY
		,@memberCredit		MONEY
		,@cashBalance		MONEY 
		,@today_cashBalance MONEY
		,@today_totalBalance MONEY
		,@totalBalance		MONEY
		,@today_Winloss		MONEY
		,@yesterday_Winloss MONEY
		,@today				DATETIME
		,@yesterday			DATETIME

SELECT @today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
SELECT @yesterday = DATEADD(dd, -1, @today)

SELECT @username = username,
		@givenCredit = ISNULL(Credit, 0) 
FROM custinfo WITH(NOLOCK) 
WHERE custid = @custid		
		
SELECT @memberCredit = ISNULL(SUM(credit), 0)
FROM custinfo WITH(NOLOCK)
WHERE srecommend = @custid AND roleid = 3

SELECT  @today_cashBalance = ISNULL(SUM(swinlost + scomm - acomm),0),
		@today_totalBalance = ISNULL(SUM(swinlost + scomm + mwinlost + awinlost + winlost - actual_stake),0),
		@today_Winloss = ISNULL(SUM(swinlost + scomm - acomm),0)
FROM bettrans b WITH(NOLOCK)
	INNER JOIN @SportBettype s ON b.bettype = s.Bettype
WHERE 
	srecommend = @custid 
	AND ruben = 1
	--AND bettype < 19001
	AND winlostdate >= @today

SELECT
	@cashBalance = ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost + scomm - acomm END),0),
	@totalBalance = ISNULL(SUM(CASE WHEN custid = srecommend THEN winlost - actual_stake ELSE swinlost+ scomm - acomm END)
					+ SUM(CASE WHEN custid = mrecommend THEN winlost - actual_stake ELSE mwinlost + acomm - comm END)
					+ SUM(CASE WHEN custid = recommend THEN winlost - actual_stake ELSE awinlost + comm - playercomm END)
					+ SUM(CASE WHEN custid <> srecommend AND custid <> mrecommend AND custid <> recommend AND ruben = 1 THEN winlost - actual_stake + playercomm ELSE 0 END),0)	
FROM bettrans WITH(NOLOCK) 
WHERE srecommend = @custid

IF @yesterday <= @MoveBetsDay
	BEGIN
		SELECT @yesterday_Winloss = ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettrans14 b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE 
			srecommend = @custid
			AND ruben = 1 
			--AND bettype < 19001
			AND winlostdate = @yesterday
	END
ELSE BEGIN
		SELECT @yesterday_Winloss = ISNULL(SUM(swinlost + scomm - acomm),0)
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN @SportBettype s ON b.bettype = s.Bettype
		WHERE 
			srecommend = @custid
			AND ruben = 1 
			--AND bettype < 19001
			AND winlostdate = @yesterday
	END
	
SELECT	@username AS username
		,@cashBalance AS cashBalance
		,@cashBalance - @today_cashBalance AS yesterday_CashBalance
		,@totalBalance AS totalBalance
		,@totalBalance - @today_totalBalance  AS yesterday_totalBalance
		,@today_Winloss AS todayWinloss
		,@yesterday_winloss AS yesterdayWinloss
		,@givenCredit AS givenCredit
		,@memberCredit AS memberCredit

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelBalanceInfo_SAg] TO [vnteam]