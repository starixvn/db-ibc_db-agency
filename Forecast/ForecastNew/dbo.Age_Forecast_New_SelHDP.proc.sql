ALTER PROCEDURE [dbo].[Age_Forecast_New_SelHDP]  
	@matchid INT,  
	@agentid INT = NULL,  
	@roleid INT = 2,  
	@bettype INT = 1  
AS
/*  
Original: Age_Forecast_SelHDP  
Task: Forecast for HDP bettype.  
DB: DB052.bodb02  
Created: 20111111@Tom  
Revisions:  
  - 20120329@Hurri: change the way to get data
  
*/
SET NOCOUNT ON  
IF @roleid = 2  
BEGIN 
	SELECT -x.hdp + score offset,
		 sum(x.hometotal) 'ht',
		 sum(x.awaytotal) 'at',
		 sum(x.homewin) 'al',
		 sum(x.awaywin) 'hl'
	FROM
	  (SELECT hdp2 - hdp1 hdp,
			  livehomescore - liveawayscore score,
			  sum(hometotalA) hometotal,
			  sum(awaytotalA) awaytotal,
			  sum(homewinA) homewin,
			  sum(awaywinA) awaywin
	   FROM
		   bettrans_forecast_agent b WITH (NOLOCK)
	   WHERE
		   bettype = @bettype
		   AND b.matchid = @matchid
		   AND b.recommend = @agentid
	   GROUP BY
		   hdp2 - hdp1, livehomescore - liveawayscore) x
	GROUP BY
	  -x.hdp + score  
End  
ELSE IF @roleid = 3  
BEGIN
	SELECT -x.hdp + score offset,
		   sum(x.hometotal) 'ht',
		   sum(x.awaytotal) 'at',
		   sum(x.homewin) 'al',
		   sum(x.awaywin) 'hl'
	FROM
		(SELECT hdp2 - hdp1 hdp,
				livehomescore - liveawayscore score,
				sum(hometotalM) hometotal,
				sum(awaytotalM) awaytotal,
				sum(homewinM) homewin,
				sum(awaywinM) awaywin
		 FROM
			 bettrans_forecast_agent b WITH (NOLOCK)
		 WHERE
			 bettype = @bettype
			 AND matchid = @matchid
			 AND b.mrecommend = @agentid
		 GROUP BY
			 hdp2 - hdp1, livehomescore - liveawayscore) x
	GROUP BY
		-x.hdp + score  
End  
ELSE IF @roleid = 4  
BEGIN
	SELECT -x.hdp + score offset,
		   sum(x.hometotal) 'ht',
		   sum(x.awaytotal) 'at',
		   sum(x.homewin) 'al',
		   sum(x.awaywin) 'hl'
	FROM
		(SELECT hdp2 - hdp1 hdp,
				livehomescore - liveawayscore score,
				sum(hometotalS) hometotal,
				sum(awaytotalS) awaytotal,
				sum(homewinS) homewin,
				sum(awaywinS) awaywin
		 FROM
			 bettrans_forecast_agent b WITH (NOLOCK)
		 WHERE
			 bettype = @bettype
			 AND matchid = @matchid
			 AND b.srecommend = @agentid
		 GROUP BY
			 hdp2 - hdp1, livehomescore - liveawayscore) x
	GROUP BY
		-x.hdp + score  
End  
GO
GRANT EXECUTE ON [dbo].[Age_Forecast_New_SelHDP] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Forecast_New_SelHDP] TO [bodbDownlineNetView]