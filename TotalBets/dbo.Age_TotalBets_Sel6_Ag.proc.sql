Alter PROCEDURE [dbo].[Age_TotalBets_Sel6_Ag]
	@custid int,
	@Language varchar(2) = 'E'
AS
/*
DB: DB053.bodb02
Revisions:
	- 02/22/2006: remove refno
	- 03/10/2006: remove odds depend
	- 18/12/2008: changed isNeutral
	- 20090216@Kiwi: + Remove to select columns: oddsid, liveindicatior, bettype, leagueid, showtime 
					 + Remove unnecessary condition: bettrans.liveindicator=0
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
*/					 
SET NOCOUNT ON
SELECT   
	bettrans.matchid,
	m.homeid,
	m.awayid,
	matchcode,
	
	sum((Case betteam when '0-1'  then (stake*odds)-stake else -stake end )*(bettrans.apositiontaking)) AS total01,
	sum((Case betteam when '2-3'  then (stake*odds)-stake else -stake end )*(bettrans.apositiontaking)) AS total23,
	sum((Case betteam when '4-6'  then (stake*odds)-stake else -stake end )*( bettrans.apositiontaking)) AS total46,
	sum((Case betteam when '7-over'  then (stake*odds)-stake else -stake end )*(bettrans.apositiontaking)) AS total7over,
	isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral
	
FROM  bettrans with (nolock)
	inner join match m with (nolock) on m.matchid = bettrans.matchid 

WHERE    
	bettrans.recommend=@custid 
	AND bettrans.bettype =6 
	AND m.eventstatus = 'running'
	--AND bettrans.status = 'running'
	AND bettrans.statusID = 0  
	AND (	IsNull(bettrans.SecAcceptFlag, 0) = 0	
			OR (IsNull(bettrans.SecAcceptFlag, 0) = 1 AND IsNull(bettrans.checktime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP )
		)
	AND bettrans.ruben = 0
GROUP BY
	bettrans.matchid,
	m.homeid,
	m.awayid,
	matchcode,
	m.isNeutral

order by m.matchcode

GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel6_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel6_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel6_Ag] TO [vnteam]
