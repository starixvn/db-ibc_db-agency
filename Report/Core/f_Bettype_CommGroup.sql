/*<info serverAlias="DBAGE-bodb02" selecters="bodbDownlineNet,bodbDownlineNetView" isFunction="1" isNested="1"></info>*/
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
		- 20171020@Percy: Add Bullfighting [RedmineID: #84690]
		- 20171215@Percy: Add missing some bettypes of Sportbook [RedmineID: #87947]
		- 20180315@Percy: Add bettypes of FM2 [RedmineID: #91902]
		- 20180717@Louis: Add bettypes of Poker Games [RedmineID: #97785]
		- 20181023@Razor: Add bettypes of eSport 2 [RedmineId: #102924]
		- 20190525@Razor: Add bettypes of BetBuilder [RedmineId: #108791]
		- 20190612@Percy: Add bettypes of Card Club [RedmineID: #115611]
		- 20190717@Razor: PHAIO Phase 4a, add 3 new bettypes [RedmineID: #117061]
		- 20190816@Percy: Add bettypes of PHAIO Phase 4b + Move 206,207,208,209 from Comm3 to Comm1 [RedmineID: #117068]
		- 20190826@Percy: Remove inactive products [RedmineID: #118699]
		- 20101021@Razor: Add BMAIO [RedmineID: #121631]
		- 20191226@Percy: Add bettypes of PHAIO Phase 5 [RedmineID: #125126]
		- 20200329@Sophia: Add Sexy Gaming and SA Gaming [RedmineID: #130670] 
		- 20200408@Sophia: Add Table Games [RedmineId: #129438]
		- 20200410@Sophia: Add BBIN [RedmineId: #131358]
		- 20200422@Sophia: Add GT Casino [RedmineId: #130693]	

	- Columns:
		- CommGroup:
			1: Comm_1 (Asian HDP, OU, OE)
			2: Comm_2 (1X2)
			3: Comm_3 (Other bettypes)
			4: Casino Comm
	- isShow: show information on Member Commission Page
*/

RETURN

SELECT bettype, CommGroup,
	CASE WHEN bettype IN (1308,1312,1316,157,178,183,411,428,432,434,435,1311,430,461,462,463,464) THEN 0 ELSE 1 END isShow
FROM (
	SELECT bettype, 1 AS CommGroup
	FROM (
		VALUES 
			(1),(3),(7),(8),(2),(12),(13),(25),(27),(28),
			(121),(122),(123),
			(128),(136),(137),(138),(139),
			(153),(155),(156),
			(1303),(1305),(1306),(1308),(1312),(1316),(1318),
			(157),(178),(183),(184),(185),(189),(190),(191),(194),(197),
			(198),(203),(204),(205),(206),(207),(208),(209),
			(801),(803),(804),(805),(806),
			(401),(402),(403),(404),(411),
			(428),(432),(434),(435),
			(17),(18),
			(609),(610),(611),(615),(616),
			(461),(462),(463),(464),
			(453),
			(470),(471),(472),(477),(478),(482),(483),(484),(485),(488),(489),(490),(491),(492),(497),
			(9002),(9003),(9005),(9008),(9009),(9012),(9013),(9018),(9019),(9024),(9025),(9028),(9029),(9034),(9035),(9040),(9041),(9046),(9047),(9052),(9053),(9058),(9059),(9060),(9061),(9070),(9071),(9074),(9076),(9078),(9079),(9080),(9081),(9082),(9083),(9084),(9085),(9086),
			(701),(702),(704),(705),(706),(708),(709),(710),
			(381),(382),(383),(386),(387),(388),(389),(390),(393),(394),(400)
		)
	A (bettype)

	UNION ALL
	SELECT bettype, 2 AS CommGroup
	FROM (
		VALUES 
			(5),(15),(167),(176),(177),(20),(21),(154),
			(1301),(1311),(1324),(501),
			(430),
			(603),(604),(605),(606),(607),(612),(613),(617),
			(458),(459),
			(9001),(9006),(9007),(9011),(9015),(9016),(9017),(9021),(9022),(9023),(9027),(9031),(9032),(9033),(9037),(9038),(9039),(9043),(9044),(9045),(9049),(9050),(9051),(9055),(9056),(9057),(9062),(9063),(9064),(9068),(9072),(9073),(9069),(9075),
			(707),(712),(713),(714),
			(385)
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
			(199),(200),(201),(202),(210),
			(211),(212),(213),(214),(215),(216),(217),
			(405),(406),(407),(408),(409),(410),(412),(413),(414),
			(415),(416),(427),(431),(433),(436),(437),
			(438),(439),(440),(441),(442),(443),(444),
			(417),(418),(419),(420),(421),(422),(423),
			(424),(425),(426),(429),(445),(446),(447),
			(221),(222),(223),(224),(225),(226),(227),
			(601),(602),(608),(614),
			(22),(143),(144),
			(448),(449),(450),(451),(452),(454),(455),(456),(457),(460),
			(38),
			(467),(468),(469),
			(473),(474),(475),(476),(479),(481),(486),(487),(493),(494),(495),(496),
			(703),(711),
			(384),(391),(392),(395),(396),(397),(398),(399)
		)
	C (bettype)

	UNION ALL
	SELECT typeid AS bettype, 4 AS CommGroup
	FROM bettype WITH(NOLOCK)
	WHERE
		typeid IN (71)
		OR typeid BETWEEN 81 AND 120
		OR typeid BETWEEN 1501 AND 1599
		OR typeid BETWEEN 1701 AND 1799
		OR typeid BETWEEN 2101 AND 2399
		OR typeid BETWEEN 2401 AND 2499
		OR typeid BETWEEN 4001 AND 7999
		OR typeid BETWEEN 2501 AND 2699
		OR typeid BETWEEN 2901 AND 2999
		OR typeid BETWEEN 1901 AND 1999
		OR typeid BETWEEN 3001 AND 3099
		OR typeID BETWEEN 3101 AND 3199
		OR TypeID BETWEEN 4901 AND 5000
		OR TypeID BETWEEN 3300 AND 3399
		OR TypeID BETWEEN 3201 AND 3299
		
) AS A
GO