/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel6_MAg]
	@custid int,
	@Language varchar(2) = 'E'
AS
/*
DB: DB042.bodb02
Revisions:
	- 02/22/2006: remove refno
	- 03/10/2006: remove odds depend
	- 20090216@Kiwi: Remove to select columns: oddsid, liveindicatior, bettype, leagueid, showtime
	- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20140416@Dom: Add First Half Total Goal (1H Total Goal) (126)
	- 20140814@Dom:  [Redmine: #19661] Offering 11 new bettypes - Include 7&Over, 4&over
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757] 
*/
BEGIN
	SET NOCOUNT ON
	SELECT   
		bettrans.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		sum((Case when  betteam = '0-1' and bettype = 6 then (stake*odds)-stake else case when bettype = 126 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [6_total01],
		sum((Case when  betteam = '2-3' and bettype = 6  then (stake*odds)-stake else case when bettype = 126 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [6_total23],
		sum((Case when  betteam = '4-6' and bettype = 6 then (stake*odds)-stake else case when bettype = 126 then 0 else -stake end end )*( bettrans.mpositiontaking)) AS [6_total46],
		sum((Case when  betteam IN ('7-over','7&over')  and bettype = 6 then (stake*odds)-stake else case when bettype = 126 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [6_total7over],

		sum((Case when betteam = '0-1' and bettype = 126 then (stake*odds)-stake else case when bettype = 6 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [126_total01],
		sum((Case when betteam = '2-3' and bettype = 126 then (stake*odds)-stake else case when bettype = 6 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [126_total23],
		sum((Case when betteam IN ('4-over','4&over') and bettype = 126 then (stake*odds)-stake else case when bettype = 6 then 0 else -stake end end )*(bettrans.mpositiontaking)) AS [126_total4over],

		sum(case when bettype=6 then 1 else 0 end) [betcount_6],
		sum(case when bettype=126 then 1 else 0 end) [betcount_126],

		isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral

	FROM  bettrans WITH (NOLOCK, INDEX =IX_betrunning_mrecommend )
		inner join match m WITH (NOLOCK) ON m.matchid = bettrans.matchid
		
	WHERE    
		bettrans.bettype IN( 6,126 )
		AND m.eventstatus='running'
		--AND bettrans.status = 'running'
		AND bettrans.statusID IN (0,1)
		AND (	IsNull(bettrans.SecAcceptFlag, 0) = 0	
				OR (IsNull(bettrans.SecAcceptFlag, 0) = 1 AND IsNull(bettrans.checktime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP )
			)
		and bettrans.mrecommend=@custid 
		
	group by 
		bettrans.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		m.isNeutral
	order by m.matchcode
END	
GO