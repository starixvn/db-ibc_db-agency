
ALTER PROCEDURE [dbo].[Age_Forecast_OddsSelTopByMatch]
	@matchid INT,
	@Language NVARCHAR(2) = 'E',
	@bettype INT = 1  
AS
/*
	Task: Forecast at Agent Site 
	DB: DB052.bodb02
	Original:OddsSelTopByMatch
	
	Revisions: 
		- 20100721@Jacob: Add param @bettype 
		- 20130730@Lukas: get live score from match instead odds		
		
*/
SET NOCOUNT ON
SELECT 	
	TOP 1 hdp1, 
	hdp2, 
	odds1a, 
	odds2a,
	ISNULL(m.livehomescore,0) livehomescore,
	ISNULL(m.liveawayscore,0) liveawayscore, 
	switch, 
	oddsstatus,
	m.homeid,
	m.awayid,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral	
FROM 
	odds WITH(NOLOCK)
	left join match M with (nolock) on odds.matchid = M.matchid 		
WHERE 
	bettype = @bettype AND
	odds.matchid = @matchid
ORDER BY 
	oddsid DESC

GO

GRANT EXECUTE ON [dbo].Age_Forecast_OddsSelTopByMatch TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Forecast_OddsSelTopByMatch TO [bodbDownlineNetView]
