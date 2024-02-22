/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02" selecters="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_GroupBettype] ()
RETURNS TABLE
RETURN

/*
	Created: 20141016@Sophia
	Task:	Get grouped bettype
	DB:		DBAGE-bodb02,DBEXT-bodb02,DBACC-bodb02
 	
	Revisions: 
		- 20150414@Sophia: Support BetRadar
		- 20151204@Bobby: Grouped 6 bettypes for PH AIO
		- 20160119@Sophia: PH AIO phase 1.2 [Redmine: #51029]
		- 20160426@Sophia: Change to in line Func-High Availability Step 4 [Redmine: #55746]
		- 20160712@Percy: PH AIO phase 2 [Redmine: #53152]
		- 20161007@Sophia: PHAIO Phase 2 , add more couple of Parent - Child [Redmine: #65406]
		- 20170919@Percy: PHAIO Phase 3, add 4 new bettypes 461 - 464 [RedmineID: #83356]
		- 20190805@Sophia: PHAIO 4B, Bettype 470 -> 497, Change GroupTypeId of 11, 199 [RedmineID: #115231]
		- 20191118@Percy: BMAIO - Add bet type 1302 (703) [RedmineID: #118622]
		- 20191226@Percy: Apply column DisplayedTypeId on bettype table [RedmineID: #125126]
		- 20230807@Danny: deploy SP in DBBOF [RedmineID: #191715]
		- 20240119@Lewis: merge bettype for VirtualSport (1,2,3) [RedmineID: #198008]

	Remark: Sportsbook only
*/
	WITH CTE_bettype AS
	(
		SELECT bt.typeid AS bettype, bt.DisplayedTypeId AS GroupTypeId
		FROM dbo.bettype bt WITH (NOLOCK)
		WHERE bt.typeid <> bt.DisplayedTypeId
			AND EXISTS (SELECT 1 FROM dbo.SportBettypeMatrix s WITH (NOLOCK) WHERE bt.typeid = s.bettype AND s.ProductId IN (1,5,27,49,77))
	)
	SELECT DISTINCT t.bettype, t.GroupTypeId
	FROM CTE_bettype b
		CROSS APPLY (
			SELECT bettype, GroupTypeId
			UNION ALL
			SELECT GroupTypeId, GroupTypeId
		) t
GO