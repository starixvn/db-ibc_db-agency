/*<info serverAlias="DBAGE-bodb02,DBTXN-bodb02,DBACC-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
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
		- 20200918@Malcolm: Add Joker [redmine: #131609]
		- 20200915@Malcolm: Add WM Live Casino [redmine: #131584]
		- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
		- 20201124@Malcolm: Add Virtual Sports 3 [redmine: #131375]
		- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
		- 20201228@Malcolm: Add MaxGame [redmine: #147572]
		- 20210203@Malcolm: Add Saba Promotion [redmine: #149952]
		- 20210302@Malcolm: Add Sports Lottery [redmine: #147362]
		- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
		- 20210301@Malcolm: Add Habanero [RedmineId : #145457]
		- 20210406@Malcolm: Add Creative Gaming [redmine: #146017]
		- 20210427@Malcolm: Add VGaming [RedmineId : #153938]
		- 20210518@Malcolm: Add AdvantPlay Mini [redmine: #155131]
		- 20210512@Malcolm: Add AdvantPlay Product [redmine: #154256]
		- 20210609@Malcolm: Add AE Sexy - [Redmine: #156239]	
		- 20210810@Evan: Add Bitcoin product - [Redmine: #159036]	
		- 20220106@Evan: Add SG Jackpot - [Redmine: #166685]
		- 20220124@Evan: Add Allbet Promotion - [Redmine: #166981]
		- 20220208@Evan: Add FGG product - [Redmine: #165685]	
		- 20220208@Danny: Add Saba Sport - [Redmine: #167177]
		- 20220825@Eddie: Add SEAL Entertainment  [RedmineID: #176078]
		- 20220907@Eddie: Add Microgaming  [RedmineId: #175850]
		- 20221012@Eddie: Add Microgaming Tournament Prize [RedmineID: #178335]
		- 20221207@Eddie: Add New SABA ESports PinGoal [RedmineID: #181383]
		- 20221215@Eddie: Change Tournament Prize to Promotion Prize [RedmineID: #181578]
		- 20230206@Eddie: Add Jili product [RedmineID: #182860]
	Paramters Explanation:
 		@ProductID: list of products
*/
RETURNS TABLE
RETURN
	SELECT ProductID, SportType, BetType, LeagueGroupID, TicketType
	FROM (
		VALUES	(1, 0, 0, 0, 0), -- Normal Sportsbook,
				(1, 0, 0, 0, 1), -- CashOut,
				(1, 1, 0, 42, 0), -- SABA Soccer,
				(1, 1, 0, 74, 0), -- SABA Soccer,
				(1, 1, 0, 108, 0), -- SABA Soccer,
				(1, 2, 0, 42, 0), -- SABA Basketball,
				(1, 50, 0, 42, 0), -- SABA Cricket,
				(1, 1, 0, 113, 0), -- SABA Soccer PinGoal,
				(1, 2, 0, 122, 0), -- SABA Basketball PinGoal,
				(1, 43, 0, 151, 0), -- SABA ESports PinGoal
				(6, 251, 71, 0, 0), (6, 208, 0, 0, 0), (6, 209, 0, 0, 0), (6, 210, 0, 0, 0), --RNG Casino
				(3, 161, 0, 0, 0), --Number Game
				(5, 180, 0, 0, 0), --Virtual Sports
				(8, 202, 0, 0, 0), --Keno
				(12, 255, 0, 0, 0), --Gold Deluxe
				(15, 204, 0, 0, 0), --Colossus Bets
				(21, 211, 0, 0, 0), --Allbet Normal Bets
				(21, 211, 2499, 0, 0), --Allbet Promotion
				(22, 212, 0, 0, 0), --Macau Games
				(23, 213, 0, 0, 0), --NG2
				(24, 219, 0, 0, 0), --Fishing World
				(27, 190, 0, 0, 0), --Betradar Virtual Sports
				(28, 220, 0, 0, 0), -- Keno
				(32, 248, 0, 0, 0), -- PP Normal Bet
				(32, 248, 4297, 0, 0), -- PP Jackpot Contribution
				(32, 248, 4298, 0, 0), -- PP Jackpot Prize
				(34, 165, 0, 0, 0), -- Card Club
				(36, 247, 0, 0, 0), -- SG Normal Bet
				(36, 247, 4599, 0, 0), -- SG Jackpot Contribution
				(36, 247, 4600, 0, 0), -- SG Jackpot Prize
				(38, 245, 0, 0, 0), -- Virtual Games
				(39, 244, 0, 0, 0), -- SA Gaming
				(42, 200, 0, 0, 0), -- Saba.club Normal Bets
				(43, 223, 0, 0, 0), -- Indo 4D	
				(45, 243, 0, 0, 0), -- AE Sexy Normal Bets
				(45, 243, 3150, 0, 0), -- AE Sexy Lucky Draw
				(40, 222, 0, 0, 0), -- Table Games	
				(47, 241, 0, 0, 0), -- BBIN
				(46, 242, 0, 0, 0), -- IBCBet Live Casino
				(50, 224, 0, 0, 0), -- RNG War
				(52, 225, 0, 0, 0), -- ION
				(55, 232, 0, 0, 0), -- PG Soft
				(56, 234, 0, 0, 0), -- Joker
				(51, 233, 0, 0, 0), -- WM
				(59, 236, 0, 0, 0), -- GDG
				(49, 231, 0, 0, 0), -- Virtual Sports 3
				(57, 239, 0, 0, 0), -- BG
				(60, 237, 0, 0, 0), -- MaxGame
				(37, 246, 0, 0, 0), -- Saba Promotion
				(63, 169, 0, 0, 0), -- Sports Lottery
				(65, 170, 0, 0, 0),-- PP Live Casino
				(61, 238, 0, 0, 0),--Habanero
				(62, 167, 0, 0, 0), -- Creative Gaming
				(66, 171, 0, 0, 0), --VGaming
				(68, 174, 0, 0, 0), -- AdvantPlay Mini
				(67, 172, 0, 0, 0),  -- AdvantPlay Product
				(69, 175, 0, 0, 0),  -- Bitcoin product
				(70, 176, 0, 0, 0),  -- FGG product
				(72, 156, 0, 0, 0),  -- SEAL Entertainment
				(73, 155, 0, 0, 0),  -- Microgaming
				(73, 155, 8695, 0, 0),  -- Microgaming Promotion Prize
				(75, 158, 0, 0, 0)  -- Jili
		) d(ProductID, SportType, BetType, LeagueGroupID, TicketType)
	WHERE ',' + @ProductID + ',' LIKE '%,' + CAST(ProductID as varchar(3)) + ',%'
GO