/*
	Created by: Helen
	Created Date: 20160120
	Task: Implement new Forecast &Total Bet function - [Redmine: #42116]
	DB: DB053/bodb02
	
*/
CREATE NONCLUSTERED INDEX [inx_matchid_recommend] ON [dbo].[bettrans] 
(
	[matchid]
	,[recommend]
	
)
INCLUDE ([betteam],[hdp1],[hdp2]
		,[odds],[stake],[livehomescore],[liveawayscore]
		,[actual_stake],[apositiontaking],custid,transid)
WHERE [bettype] IN (1,7,3,8,5,15) AND statusID = 0

GO

CREATE NONCLUSTERED INDEX [inx_matchid_srecommend] ON [dbo].[bettrans] 
(
	[matchid]
	,[srecommend]
)
INCLUDE ([hdp1],[hdp2]
		,[odds],[stake],[livehomescore],[liveawayscore],[betteam]
		,[actual_stake],[spositiontaking],custid,transid)
WHERE [bettype] IN (1,7,3,8,5,15) AND  statusID = 0

GO

CREATE NONCLUSTERED INDEX [inx_matchid_mrecommend] ON [dbo].[bettrans] 
(
	[matchid]
	,[mrecommend]
)
INCLUDE ([hdp1],[hdp2]
		,[odds],[stake],[livehomescore],[liveawayscore],[betteam]
		,[actual_stake],[mpositiontaking],custid,transid)
WHERE [bettype] IN (1,7,3,8,5,15) AND  statusID = 0

GO

CREATE NONCLUSTERED INDEX [inx_matchid] ON [dbo].[odds] 
(
	[matchid] ASC,
	[bettype] ASC,
	[oddsstatus] ASC
) INCLUDE (hdp1,hdp2)
GO






