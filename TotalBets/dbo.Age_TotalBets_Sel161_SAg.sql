alter PROCEDURE [dbo].[Age_TotalBets_Sel161_SAg]
	@custid INT,
	@Language varchar(2) = 'E'
AS

/*
Created: 20100908@Kiwi
Task : Retrieve Total Bet values for Number Game
DB: DB052.bodb02

Revisions:
	- 20110729@Sophia: Add bettype 88,89,90
	- 20110809@Sophia: do not separate Live or Deadball to 2 row anymore
	- 20120627@Sophia: Add new bettype = 90 for NumberGroup
    
Param's Explanation:
• @custid: Super Agent ID
• Bettype and betteam explanation:
	* First ball over/under: 81, over = h , under = a
	* Last ball over/under: 82, over = h , under = a
	* First ball odd/even: 83, odd = h , even = a
	* Last ball odd/even: 84, odd = h , even = a
	* Over/Under FT: 85 (also use for LIVE over/under), over = h , under = a
	* Odd/Even FT: 86 (also use for LIVE odd/even), odd = h  , even = a
	* High/Low: 87, high = h , low = a
	* Warrior: 88, high = h , low = a
	* Next Combo: 89, OverOdd = 1:1 , OverEven = 1:2, UnderOdd = 2:1, UnderEven = 2:2
	* Number group: 90, betteam = the position of selection, hdp1 = the number ID of group
*/

SET NOCOUNT ON

SELECT 
		m.showtime, m.leagueID,	m.matchcode, m.matchid,
		sum( over_1stBall) over_1stBall,
		sum( under_1stBall) under_1stBall,
		sum( over_lastBall) over_lastBall,
		sum( under_lastBall) under_lastBall,
		sum( odd_1stBall) odd_1stBall,
		sum( even_1stBall) even_1stBall,
		sum( odd_lastBall) odd_lastBall,
		sum( even_lastBall) even_lastBall,
		sum( odd_fullTime) odd_fullTime,
		sum( even_fullTime) even_fullTime,
		sum( over_next) over_next,
		sum( under_next) under_next,
		sum( odd_next) odd_next,
		sum( even_next) even_next,		
		sum( high) high,
		sum( low) low,
		sum( Warrior_2ndBall) Warrior_2ndBall,
		sum( Warrior_3rdBall) Warrior_3rdBall,
		sum( NextCombo_OverOdd) NextCombo_OverOdd,
		sum( NextCombo_OverEven) NextCombo_OverEven,
		sum( NextCombo_UnderOdd) NextCombo_UnderOdd ,
		sum( NextCombo_UnderEven) NextCombo_UnderEven,
		sum( NumberGroupPre) NumberGroupPre,
		sum( NumberGroupLive) NumberGroupLive,
		
		sum( betcount_OU1stBall) betcount_OU1stBall,
		sum( betcount_OULastBall) betcount_OULastBall,
		sum( betcount_OE1stBall) betcount_OE1stBall,
		sum( betcount_OElastBall) betcount_OElastBall,		
		sum( betcount_OEfullTime) betcount_OEfullTime,		
		sum( betcount_OUNext) betcount_OUNext,
		sum( betcount_OENext) betcount_OENext,
		sum( betcount_highlow) betcount_highlow,
		sum( betcount_Warrior_2ndBall) betcount_Warrior_2ndBall,
		sum( betcount_Warrior_3rdBall) betcount_Warrior_3rdBall,
		sum( betcount_NextCombo_OverOdd) betcount_NextCombo_OverOdd,
		sum( betcount_NextCombo_OverEven) betcount_NextCombo_OverEven,
	    sum( betcount_NextCombo_UnderOdd) betcount_NextCombo_UnderOdd,
		sum( betcount_NextCombo_UnderEven) betcount_NextCombo_UnderEven,
		sum( betcount_NumberGroupPre) betcount_NumberGroupPre,
		sum( betcount_NumberGroupLive) betcount_NumberGroupLive
FROM (
			SELECT
					m.showtime, 
					m.leagueID,
					m.matchcode,
					b.liveindicator,
					m.matchid,
					sum(Case when bettype=81 and betteam = 'h' then Stake else 0 End) AS over_1stBall,
					sum(Case when bettype=81 and betteam = 'a' then Stake else 0 End) AS under_1stBall,
					sum(Case when bettype=82 and betteam = 'h' then Stake else 0 End) AS over_lastBall,
					sum(Case when bettype=82 and betteam = 'a' then Stake else 0 End) AS under_lastBall,
					sum(Case when bettype=83 and betteam = 'h' then Stake else 0 End) AS odd_1stBall,
					sum(Case when bettype=83 and betteam = 'a' then Stake else 0 End) AS even_1stBall,
					sum(Case when bettype=84 and betteam = 'h' then Stake else 0 End) AS odd_lastBall,
					sum(Case when bettype=84 and betteam = 'a' then Stake else 0 End) AS even_lastBall,
					
			--		sum(Case when bettype=85 and betteam = 'h' and b.liveindicator=0 then Stake else 0 End) AS over_fullTime,
			--		sum(Case when bettype=85 and betteam = 'a' and b.liveindicator=0 then Stake else 0 End) AS under_fullTime,
					sum(Case when bettype=86 and betteam = 'h' and b.liveindicator=0 then Stake else 0 End) AS odd_fullTime,
					sum(Case when bettype=86 and betteam = 'a' and b.liveindicator=0 then Stake else 0 End) AS even_fullTime,
					
					sum(Case when bettype=85 and betteam = 'h' and b.liveindicator=1 then Stake else 0 End) AS over_next,
					sum(Case when bettype=85 and betteam = 'a' and b.liveindicator=1 then Stake else 0 End) AS under_next,
					sum(Case when bettype=86 and betteam = 'h' and b.liveindicator=1 then Stake else 0 End) AS odd_next,
					sum(Case when bettype=86 and betteam = 'a' and b.liveindicator=1 then Stake else 0 End) AS even_next,		
					sum(Case when bettype=87 and betteam = 'h' then Stake else 0 End) AS high,
					sum(Case when bettype=87 and betteam = 'a' then Stake else 0 End) AS low,
					
					sum(Case when bettype=88 and betteam = 'h' then Stake else 0 End) AS Warrior_2ndBall,
					sum(Case when bettype=88 and betteam = 'a' then Stake else 0 End) AS Warrior_3rdBall,

					sum(Case when bettype=89 and betteam = '1:1' then Stake else 0 End) AS NextCombo_OverOdd ,
					sum(Case when bettype=89 and betteam = '1:2' then Stake else 0 End) AS NextCombo_OverEven,
					sum(Case when bettype=89 and betteam = '2:1' then Stake else 0 End) AS NextCombo_UnderOdd ,
					sum(Case when bettype=89 and betteam = '2:2' then Stake else 0 End) AS NextCombo_UnderEven,
					
					sum(Case when bettype=90 and b.liveindicator=0 then Stake else 0 End) AS NumberGroupPre,	
					sum(Case when bettype=90 and b.liveindicator=1 then Stake else 0 End) AS NumberGroupLive,
					
					sum(Case when bettype=81 Then BetCount else 0 End) AS betcount_OU1stBall,
					sum(Case when bettype=82 Then BetCount else 0 End) AS betcount_OULastBall,
					sum(Case when bettype=83 Then BetCount else 0 End) AS betcount_OE1stBall,
					sum(Case when bettype=84 Then BetCount else 0 End) AS betcount_OElastBall,
					
			--		sum(Case when bettype=85 and b.liveindicator=0 Then BetCount else 0 End) AS betcount_OUfullTime,
					sum(Case when bettype=86 and b.liveindicator=0 Then BetCount else 0 End) AS betcount_OEfullTime,
					
					sum(Case when bettype=85 and b.liveindicator=1 Then BetCount else 0 End) AS betcount_OUNext,
					sum(Case when bettype=86 and b.liveindicator=1 Then BetCount else 0 End) AS betcount_OENext,
					sum(Case when bettype=87 Then BetCount else 0 End) AS betcount_highlow,
					
					sum(Case when bettype=88 and betteam = 'h' then BetCount else 0 End) AS betcount_Warrior_2ndBall,
					sum(Case when bettype=88 and betteam = 'a' then BetCount else 0 End) AS betcount_Warrior_3rdBall,
					sum(Case when bettype=89 and betteam = '1:1' then BetCount else 0 End) AS betcount_NextCombo_OverOdd,
					sum(Case when bettype=89 and betteam = '1:2' then BetCount else 0 End) AS betcount_NextCombo_OverEven,
					sum(Case when bettype=89 and betteam = '2:1' then BetCount else 0 End) AS betcount_NextCombo_UnderOdd,
					sum(Case when bettype=89 and betteam = '2:2' then BetCount else 0 End) AS betcount_NextCombo_UnderEven,
					sum(Case when bettype=90 and b.liveindicator=0 Then BetCount else 0 End) AS betcount_NumberGroupPre,
					sum(Case when bettype=90 and b.liveindicator=1 Then BetCount else 0 End) AS betcount_NumberGroupLive

			FROM
				(SELECT
						matchid,
						bettype,
						betteam,
						liveindicator,
						SUM(spositiontaking * stake * case when abs(odds) <1 then 1 else abs(odds) end) Stake,
						count(1) AS BetCount
				FROM bettrans with (nolock)
				WHERE
						bettype BETWEEN 81 AND 120
						AND srecommend = @custid
						AND ruben = 0
				GROUP BY matchid, bettype, betteam, liveindicator) as b
				INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid  	
			WHERE	
				m.eventstatus = 'running'
			GROUP BY
				m.showtime, 
				m.leagueID,
				m.matchcode,
				b.liveindicator,
				m.matchid) m
	GROUP BY
			m.showtime, 
			m.leagueID,
			m.matchcode,
			m.matchid
ORDER BY	m.matchcode

GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel161_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel161_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel161_SAg] TO [vnteam]
