/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="1" isNested="1"></info>*/
USE [bodb02]
GO

ALTER FUNCTION dbo.f_Bettype_CommGroup ()
RETURNS TABLE
AS

/*
	Created by Percy
	Date: 2017-04-25
	DB: DBAGE.bodb02
	Task: Relationship between bettype and commission group

	Revisions:
		- 20170801@Percy: Add new bettype range of RnG Casino [RedmineID: #78424]
		- 20170828@Percy: Add Lucky 3 [RedmineID: #76770]
		- 20170919@Percy: PHAIO Phase 3, add 4 new bettypes 461 - 464 [RedmineID: #83356]
	
	- Columns:
		- CommGroup:
			1: Comm_1
			2: Comm_2
			3: Comm_3
			4: Casino Comm
			5: MO Comm
			6: Charge Comm
	- isShow: show information on Member Commission Page
*/

RETURN

SELECT bettype, CommGroup,
	CASE WHEN bettype IN (124,125,1308,1312,1316,157,178,183,411,428,432,434,435,1311,430,461,462,463,464) THEN 0 ELSE 1 END isShow
FROM (
	SELECT bettype, 1 AS CommGroup
	FROM (
		VALUES 
			(1),(3),(7),(8),(2),(12),(13),(25),(27),(28),
			(121),(122),(123),(124),(125),
			(128),(136),(137),(138),(139),
			(153),(155),(156),
			(1303),(1305),(1306),(1308),(1312),(1316),(1318),
			(157),(178),(183),(184),(185),(189),(190),(191),(194),(197),
			(198),(203),(204),(205),
			(801),(802),(803),(804),(805),(806),
			(401),(402),(403),(404),(411),
			(428),(432),(434),(435),
			(17),(18),
			(609),(610),(611),(615),(616),
			(461),(462),(463),(464)
		)
	A (bettype)

	UNION ALL
	SELECT bettype, 2 AS CommGroup
	FROM (
		VALUES 
			(5),(15),(167),(176),(177),(20),(21),(154),
			(1301),(1311),(1324),(501),
			(430),
			(603),(604),(605),(606),(607),(612),(613),(617)
		)
	B (bettype)

	UNION ALL
	SELECT bettype, 3 AS CommGroup
	FROM (
		VALUES 
			(30),(4),(6),(126),(9),(10),(14),(127),(16),(29),
			(133),(134),(135),(145),(146),(147),(24),(26),
			(129),(130),(131),(132),
			(148),(149),(150),(151),(152),(140),(141),(142),
			(1302),(1317),
			(159),(160),(161),(162),(163),(164),(165),(166),(168),
			(169),(170),(171),(172),(173),(174),(175),(179),(180),
			(181),(182),(186),(187),(188),(192),(193),(195),(196),
			(199),(200),(201),(202),(206),(207),(208),(209),(210),
			(211),(212),(213),(214),(215),(216),(217),
			(405),(406),(407),(408),(409),(410),(412),
			(415),(416),(427),(431),(433),(436),(437),
			(438),(439),(440),(441),(442),(443),(444),
			(417),(418),(419),(420),(421),(422),(423),
			(424),(425),(426),(429),(445),(446),(447),
			(221),(222),(223),(224),(225),
			(601),(602),(608),(614)
		)
	C (bettype)

	UNION ALL
	SELECT typeid AS bettype, 4 AS CommGroup
	FROM bettype WITH(NOLOCK)
	WHERE
		typeid IN (71,73)
		OR typeid BETWEEN 1101 AND 1150
		OR typeid BETWEEN 81 AND 120
		OR typeid BETWEEN 1501 AND 1599
		OR typeid BETWEEN 1701 AND 1799
		OR typeid BETWEEN 2101 AND 2399
		OR typeid BETWEEN 2401 AND 2499
		OR typeid BETWEEN 4001 AND 7999
		OR typeid BETWEEN 2501 AND 2699
		OR typeid BETWEEN 2901 AND 2999
		OR typeid BETWEEN 1600 AND 1610

	UNION ALL
	SELECT bettype, 5 AS CommGroup -- MO_comm
	FROM (
		VALUES 
			(301),(302),(303),(304)
		)
	D (bettype)

	UNION ALL
	SELECT 500 AS bettype, 6 AS CommGroup -- Charge_comm
) AS A

GO