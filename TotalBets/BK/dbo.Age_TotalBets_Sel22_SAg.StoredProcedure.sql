ALTER PROCEDURE [dbo].[Age_TotalBets_Sel22_SAg]
	@custid int,
	@Language varchar(2) = 'E'
AS
/*
Created: 20090204@Phuc
Task : Total bets for next goal bettype
DB: DB05.bodb02
Original:

Param's Explanation:
• @CustID: SuperID

Revisions:
	- 20090218@QuiNguyen: Add return values GoalRecord (ex: ahahha)

*/
SET NOCOUNT ON

SELECT 
	goalrecord,  --- QuiNguyen added
	showtime, 
	leagueid,	
	matchid,	
	homeid,
	awayid,
	IsNeutral,
	livehomescore,
	liveawayscore,
	sum(home_total) as home_total,
	sum(away_total) as away_total,
	sum(CASE
			WHEN modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
			WHEN modds =  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * 0.5
			WHEN modds =  0	THEN 0
			WHEN modds = -0.25	THEN actual_stake * spositiontaking * 0.5
			WHEN modds < -0.25	THEN actual_stake * spositiontaking
		END) as winlost
FROM
(
	SELECT
		m.goalrecord,  --- QuiNguyen added
		m.showtime, 
		m.leagueid,	
		m.matchid,	
		m.homeid,
		m.awayid,
		b.livehomescore,
		b.liveawayscore,
		b.stake, b.actual_stake, b.spositiontaking, b.odds,b.bettype,
		case when betteam = 'h' then (b.spositiontaking)* stake * (case when abs(odds) <1 then 1 else abs(odds) end) else 0 end AS home_total,
		case when betteam = 'a' then (b.spositiontaking)* stake * (case when abs(odds) <1 then 1 else abs(odds) end) else 0 end AS away_total,

		CASE SUBSTRING(isnull(GoalRecord,''), b.livehomescore + b.liveawayscore + 1, 1)
			WHEN N'' THEN 0 -- Not have next goal = draw (refund)
			WHEN betteam THEN 1 + CASE betteam 
									WHEN N'h' THEN (hdp2-hdp1) -- collect choose = win
									WHEN N'a' THEN (hdp1-hdp2)
									END 
			ELSE -1 + CASE betteam -- other case = lose
						WHEN N'h' THEN (hdp2-hdp1)
						WHEN N'a' THEN (hdp1-hdp2)
						END 
			END as modds,
		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	FROM
		bettrans b WITH(NOLOCK)
		INNER JOIN match m WITH (NOLOCK) ON m.matchid = b.matchid 
	WHERE 
		b.srecommend = @custid AND
		m.eventstatus = 'running'  AND
		b.bettype = 22 AND
		b.ruben=0 AND
		--b.status in ('running', 'waiting') AND --ruben = 0 included b.status in ('running','waiting')
		b.liveindicator=1
) a
GROUP BY
	homeid,
	awayid,
	matchid,		
	leagueid,	
	livehomescore,
	liveawayscore,
	goalrecord,
	showtime,
	isNeutral
ORDER BY
	matchid,livehomescore + liveawayscore desc


GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel22_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel22_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel22_SAg] TO [vnteam]