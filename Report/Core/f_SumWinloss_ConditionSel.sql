/*<info serverAlias="DBAGE-bodb02,DBTXN-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_SumWinloss_ConditionSel]
(
	@ProductID	VARCHAR(500) = ''
) 
/*
	Creator: Paul	
	Date: 20170110
	Task: Get sum_winloss condition
	DB: DBAGE.bodb02, DBTXN.bodb02
		
	Revisions:
		- 20170622@Percy: Add Betradar Virtual Sports [RedmineID: #78339]
		- 20170705@Percy: Add Keno Lottery [RedmineID: #78064]
		- 20170828@Percy: Add Lucky 3 [RedmineID: #76770]
		- 20171020@Percy: Add Bullfighting [RedmineID: #84690]
		- 20170419@Razor: Add Pragmatic [RedmineID: #92647]
		- 20180717@Louis: Add Poker Games [RedmineID: #97785]
		- 20190627@Razor: Add CardClub [RedmineID: #115611]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20191029@Percy: Add Spadegaming [RedmineID: #122353]
		- 20191224@Percy: Add Virtual Games [RedmineID: #124906]
		- 20200316@Sophia: Add SA Gaming [RedmineID: #128057]
		- 20200326@Sophia: Add Saba.club [RedmineId: #130781]
		- 20200326@Sophia: Add Sexy Gaming[RedmineId: #130670]
		- 20200326@Sophia: Add Indo 4D [RedmineId: #130236]
		- 20200408@Sophia: Add Table Games [RedmineId: #129438]
		- 20200410@Sophia: Add BBIN [RedmineId: #131358]
		- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
		- 20200527@Sophia: Add ION [Redmine: #132325]
		- 20200528@Sophia: Add RNG War [Redmine: #132013]
		- 20200810@Sophia: Add PG Soft[Redmine: #137767]
		- 20200908@Malcolm : Report Enhancement for Jackpot Product Filter [RedmineID : #139575]
	Paramters Explanation:
 		@ProductID: list of products
*/
RETURNS TABLE
RETURN
	SELECT ProductID, SportType, BetType
	FROM (
		VALUES	(1, 0, 0), --Sportsbook
				(6, 251, 71), (6, 208, 0), (6, 209, 0), (6, 210, 0), --RNG Casino
				(3, 161, 0), --Number Game
				(5, 180, 0), --Virtual Sports
				(8, 202, 0), --Keno
				(12, 255, 0), --Gold Deluxe
				(15, 204, 0), --Colossus Bets
				(21, 211, 0), --Allbet
				(22, 212, 0), --Macau Games
				(23, 213, 0), --NG2
				(24, 219, 0), --Fishing World
				(27, 190, 0), --Betradar Virtual Sports
				(28, 220, 0), -- Keno
				(32, 248, 0), -- PP Normal Bet
				(32, 248, 4297), -- PP Jackpot Contribution
				(32, 248, 4298), -- PP Jackpot Prize
				(34, 165, 0), -- Card Club
				(36, 247, 0), -- Spadegaming
				(38, 245, 0), -- Virtual Games
				(39, 244, 0), -- SA Gaming
				(42, 200, 0), -- Saba.club Normal Bets
				(43, 223, 0), -- Indo 4D	
				(45, 243, 0), -- Sexy Gaming
				(40, 222, 0), -- Table Games	
				(47, 241, 0), -- BBIN
				(46, 242, 0), -- IBCBet Live Casino
				(50, 224, 0), -- RNG War
				(52, 225, 0), -- ION
				(55, 232, 0)  -- PG Soft
		) d(ProductID, SportType, BetType)
	WHERE ',' + @ProductID + ',' LIKE '%,' + CAST(ProductID as varchar(3)) + ',%'
GO