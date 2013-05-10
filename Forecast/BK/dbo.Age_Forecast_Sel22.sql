 ALTER PROCEDURE [dbo].[Age_Forecast_Sel22]
	@matchid INT ,	
	@custid INT,
	@roleid INT = 2
AS
/*
Created: 20090207@Hanh
Task: Forecast for next goal bettype
DB: DB05.bodb02
Revisions: 
	- 20090213@Kiwi: + Remove custid>0 and custid <>0
						  + At Super level (@roleid = 4): remove b.status in ('running','waiting') to use correct Index named _MS_Sys_38_52_42.
	- 20090314@Daniel: Add ISNULL for condition LEN(m.goalrecord) = b.livehomescore + b.liveawayscore: isnull(LEN(m.goalrecord),0) = b.livehomescore + b.liveawayscore 
	-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement

Param's Explanation:
• @CustID: agentID/masterID/superID
*/
SET NOCOUNT ON
IF @roleid=2
BEGIN
	SELECT TOP 1
		showtime, 
		leagueid,			
		homeid,
		awayid,
		livehomescore,
		liveawayscore,
		IsNeutral,
		-1*away_lose as away_lose,
		-1*home_lose as home_lose,
		-1*no_goal as no_goal
	FROM
	(SELECT 
		m.showtime, 
		m.leagueid,			
		m.homeid,
		m.awayid,
		b.livehomescore,
		b.liveawayscore,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN 1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN 1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 =  0	THEN 0
											WHEN 1 + hdp2 - hdp1 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 < -0.25	THEN actual_stake * apositiontaking
										  END
				 WHEN betteam = 'a' THEN CASE
											WHEN -1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN -1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 =  0	THEN 0
											WHEN -1 + hdp1 - hdp2 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 < -0.25	THEN actual_stake * apositiontaking
										  END 
				 ELSE 0 END) AS away_lose,

		SUM(CASE WHEN betteam = 'a' THEN CASE
											WHEN 1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN 1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 =  0	THEN 0
											WHEN 1 + hdp1 - hdp2 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 < -0.25	THEN actual_stake * apositiontaking
										  END 
				 WHEN betteam = 'h' THEN CASE
											WHEN -1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN -1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 =  0	THEN 0
											WHEN -1 + hdp2 - hdp1 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 < -0.25	THEN actual_stake * apositiontaking
										  END 
				 ELSE 0 END) AS home_lose,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN hdp2 - hdp1 =  0	THEN 0
											WHEN hdp2 - hdp1 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN hdp2 - hdp1 < -0.25	THEN actual_stake * apositiontaking
										  END 
				 WHEN betteam = 'a' THEN CASE
											WHEN hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking
											WHEN hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -apositiontaking * 0.5
											WHEN hdp1 - hdp2 =  0	THEN 0
											WHEN hdp1 - hdp2 = -0.25	THEN actual_stake * apositiontaking * 0.5
											WHEN hdp1 - hdp2 < -0.25	THEN actual_stake * apositiontaking
										  END
				 ELSE 0 END) AS no_goal,		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans b WITH(NOLOCK)
		INNER JOIN MATCH m WITH (NOLOCK) ON m.matchid = b.matchid 
	WHERE 
		b.recommend = @custid AND
		m.eventstatus = 'running'  AND
		b.bettype = 22 AND
		b.matchid=@matchid AND
		b.ruben=0 AND
		--b.status IN ('running', 'waiting') AND
		b.statusID in (0,1) AND
		b.liveindicator=1 AND
		isnull(LEN(m.goalrecord),0) = b.livehomescore + b.liveawayscore
	
	GROUP BY
		m.homeid,
		m.awayid,		
		m.leagueid,		
		b.livehomescore,
		b.liveawayscore,
		m.showtime,
		m.isNeutral
	)a
	ORDER BY
		livehomescore + liveawayscore DESC
END
ELSE IF @roleid=3
BEGIN
	SELECT TOP 1
		showtime, 
		leagueid,			
		homeid,
		awayid,
		livehomescore,
		liveawayscore,
		IsNeutral,
		-1*away_lose as away_lose,
		-1*home_lose as home_lose,
		-1*no_goal as no_goal
	FROM
	(SELECT 
		m.showtime, 
		m.leagueid,			
		m.homeid,
		m.awayid,
		b.livehomescore,
		b.liveawayscore,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN 1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN 1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 =  0	THEN 0
											WHEN 1 + hdp2 - hdp1 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 < -0.25	THEN actual_stake * mpositiontaking
										  END
				 WHEN betteam = 'a' THEN CASE
											WHEN -1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN -1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 =  0	THEN 0
											WHEN -1 + hdp1 - hdp2 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 < -0.25	THEN actual_stake * mpositiontaking
										  END 
				 ELSE 0 END) AS away_lose,

		SUM(CASE WHEN betteam = 'a' THEN CASE
											WHEN 1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN 1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 =  0	THEN 0
											WHEN 1 + hdp1 - hdp2 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 < -0.25	THEN actual_stake * mpositiontaking
										  END 
				 WHEN betteam = 'h' THEN CASE
											WHEN -1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN -1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 =  0	THEN 0
											WHEN -1 + hdp2 - hdp1 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 < -0.25	THEN actual_stake * mpositiontaking
										  END 
				 ELSE 0 END) AS home_lose,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN hdp2 - hdp1 =  0	THEN 0
											WHEN hdp2 - hdp1 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN hdp2 - hdp1 < -0.25	THEN actual_stake * mpositiontaking
										  END 
				 WHEN betteam = 'a' THEN CASE
											WHEN hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking
											WHEN hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -mpositiontaking * 0.5
											WHEN hdp1 - hdp2 =  0	THEN 0
											WHEN hdp1 - hdp2 = -0.25	THEN actual_stake * mpositiontaking * 0.5
											WHEN hdp1 - hdp2 < -0.25	THEN actual_stake * mpositiontaking
										  END
				 ELSE 0 END) AS no_goal,		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans b WITH(NOLOCK)
		INNER JOIN MATCH m WITH (NOLOCK) ON m.matchid = b.matchid 
	WHERE 
		b.mrecommend = @custid AND
		m.eventstatus = 'running'  AND
		b.bettype = 22 AND
		b.matchid=@matchid AND
		b.ruben=0 AND
		--b.status IN ('running', 'waiting') AND
		b.statusID in (0,1) AND
		b.liveindicator=1 AND
		isnull(LEN(m.goalrecord),0) = b.livehomescore + b.liveawayscore
	
	GROUP BY
		m.homeid,
		m.awayid,		
		m.leagueid,		
		b.livehomescore,
		b.liveawayscore,
		m.showtime,
		m.isNeutral
	)a
	ORDER BY
		livehomescore + liveawayscore DESC
END
ELSE IF @roleid=4
BEGIN
	SELECT TOP 1
		showtime, 
		leagueid,			
		homeid,
		awayid,
		livehomescore,
		liveawayscore,
		IsNeutral,
		-1*away_lose as away_lose,
		-1*home_lose as home_lose,
		-1*no_goal as no_goal
	FROM
	(SELECT 
		m.showtime, 
		m.leagueid,			
		m.homeid,
		m.awayid,
		b.livehomescore,
		b.liveawayscore,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN 1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN 1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 =  0	THEN 0
											WHEN 1 + hdp2 - hdp1 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN 1 + hdp2 - hdp1 < -0.25	THEN actual_stake * spositiontaking
										  END
				 WHEN betteam = 'a' THEN CASE
											WHEN -1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN -1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 =  0	THEN 0
											WHEN -1 + hdp1 - hdp2 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN -1 + hdp1 - hdp2 < -0.25	THEN actual_stake * spositiontaking
										  END 
				 ELSE 0 END) AS away_lose,

		SUM(CASE WHEN betteam = 'a' THEN CASE
											WHEN 1 + hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN 1 + hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 =  0	THEN 0
											WHEN 1 + hdp1 - hdp2 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN 1 + hdp1 - hdp2 < -0.25	THEN actual_stake * spositiontaking
										  END 
				 WHEN betteam = 'h' THEN CASE
											WHEN -1 + hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN -1 + hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 =  0	THEN 0
											WHEN -1 + hdp2 - hdp1 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN -1 + hdp2 - hdp1 < -0.25	THEN actual_stake * spositiontaking
										  END 
				 ELSE 0 END) AS home_lose,
		SUM(CASE WHEN betteam = 'h' THEN CASE
											WHEN hdp2 - hdp1 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN hdp2 - hdp1 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN hdp2 - hdp1 =  0	THEN 0
											WHEN hdp2 - hdp1 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN hdp2 - hdp1 < -0.25	THEN actual_stake * spositiontaking
										  END 
				 WHEN betteam = 'a' THEN CASE
											WHEN hdp1 - hdp2 >  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking
											WHEN hdp1 - hdp2 =  0.25	THEN stake * (CASE WHEN odds<0 THEN 1 ELSE odds END) * -spositiontaking * 0.5
											WHEN hdp1 - hdp2 =  0	THEN 0
											WHEN hdp1 - hdp2 = -0.25	THEN actual_stake * spositiontaking * 0.5
											WHEN hdp1 - hdp2 < -0.25	THEN actual_stake * spositiontaking
										  END
				 ELSE 0 END) AS no_goal,		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
	FROM
		bettrans b WITH(NOLOCK)
		INNER JOIN MATCH m WITH (NOLOCK) ON m.matchid = b.matchid 
	WHERE 
		b.srecommend = @custid AND
		m.eventstatus = 'running'  AND
		b.bettype = 22 AND
		b.matchid=@matchid AND
		b.ruben=0 AND
		--b.status in ('running', 'waiting') AND
		b.liveindicator=1 AND
		isnull(LEN(m.goalrecord),0) = b.livehomescore + b.liveawayscore
	
	GROUP BY
		m.homeid,
		m.awayid,		
		m.leagueid,		
		b.livehomescore,
		b.liveawayscore,
		m.showtime,
		m.isNeutral
	)a
	ORDER BY
		livehomescore + liveawayscore DESC

END
GO
GRANT EXECUTE ON [dbo].[Age_Forecast_Sel22] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Forecast_Sel22] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Forecast_Sel22] TO [vnteam]


