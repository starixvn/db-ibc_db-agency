/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0"></info>*/	
ALTER PROCEDURE [dbo].[Age_TotalBets_Sel10_SAg]
	@custid int,
	@Language varchar(2) = 'E'
AS

/*
Created: 20090122@Thien
Task : Retrieve Total Bet values for bettype 10
DB: DBBOF.bodb02

Revisions:
    - 20060222: remove refno 
	- 20090217@HanhVu: change the formula of totalwinlost value (member's won - member's lose)
	-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
	- 20180802@Helen: Update code for adjusting indexes - [Redmine:98757] 
	- 20201005@Danny: Change to use alias DBBOF alternative to DB042 [RedmineID: #139516]
	
Param's Explanation:
• @custid: Super Agent ID
*/
BEGIN
	SET NOCOUNT ON
	select
		m.leagueid, 	
		m.matchcode, m.orid,
		m.teamid,
		sum(a.spositiontaking*stake) AS balance,
		sum(1) as BetCount,
		sum(a.spositiontaking*stake*a.odds) - isnull(leaguetotal.totalbalance, 0) as totalwinlost,
		CONVERT(BIT,0) as IsNeutral
	FROM
		bettrans AS a  WITH (NOLOCK)
		INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid     = a.matchid 
		INNER JOIN 	(
					select 
						m.leagueid, sum(a.spositiontaking*stake) as totalbalance
					FROM
						bettrans AS a  WITH (NOLOCK)
						INNER JOIN outright AS m  WITH (NOLOCK) ON m.orid     = a.matchid 
						
					where  	
						a.srecommend=@custid and
						a.statusID IN (0,1) and
						a.bettype = 10
					group by m.leagueid
				) as leaguetotal ON leaguetotal.leagueid = m.leagueid
	where  	
		a.srecommend=@custid and
		a.statusID IN (0,1) and
		a.bettype = 10
	group by 
		m.orid,
		m.matchcode, 
		m.teamid,
		leaguetotal.totalbalance,
		m.leagueid
		
	order by m.matchcode desc
END
GO