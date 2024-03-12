/*<info serverAlias="DBAGE-bodb02,DBACC-bodb02,DBTP-bodb02" selecters="wsv_alp,wsv_alpv" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Bettype_CommGroup ()
RETURNS TABLE
AS

/*
	Created by Percy
	Date: 2017-04-25
	DB: DBAGE.bodb02,DBACC-bodb02,DBTP-bodb02
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
		- 20200422@Sophia: Add IBCBet Live Casino [RedmineId: #130693]
		- 20200514@Percy: Add 2 bettypes of E-Sports 3 [RedmineID: #132386]
		- 20200518@Percy: Add bettypes of PHAIO 5.1 [RedmineID: #132770]
		- 20200527@Sophia: Add ION [Redmine: #132325]
		- 20200709@Sophia: Add BAIO [Redmine: #137318]
		- 20201013@Percy: Add Time Machine OU bettype (228) [RedmineID: #141998]
		- 20200915@Malcolm: Add WM Live Casino [Redmine : #131584]
		- 20201201@Malcolm : Add Gold Diamond Gaming [Redmine : #144110]
		- 20201201@Malcolm : Separate the bettype range (4001 -> 7999) into bettype ranges of multiple game [RedmineId : #131375]
		- 20201210@Malcolm: Add Big Gaming [RedmineId : #142459]
		- 20210305@Malcolm: add new bettype for cricket AIO  - [RedminedId : #148454]
		- 20210310@Malcolm: Add Pragmatic Live Casino [RedmineId : #133717]
		- 20210412@Malcolm: Add Time Machine HDP bettype (229) [RedmineID: #152749]
		- 20210810@Evan: Add Bitcoin product - [Redmine: #159036]	
		- 20210305@Malcolm: add new bettype for cricket AIO Phase 2 - [RedminedId : #154810]
		- 20211214@Evan: Add New Games for PP - [Redmine: #165393]	
		- 20220303@Evan: Add bettypes of E-Sports 4 - [Redmine: #166326]
		- 20220303@Evan: Add bettypes of Cricket - [Redmine: #166332]
		- 20220328@Evan: Expand bettype range of Macau Games - [Redmine: #170383]
		- 20220707@Evan: Expand bettype range of Volleyball [Redmine: #173861]
		- 20230810@Lewis: Add 4 new bettypes of Basketball AIO [Redmine: #191334]
		- 20240202@Lewis: Move bettype 219 from CommGr 2 => CommGr1 [Redmine: #200765]
		- 20240223@Lewis: Add WE Live Casino [Redmine: #195885]
		- 20240312@Lewis: Add metadata DBACC-bodb02 , DBTP-bodb02 [Redmine: #193083]

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
			(381),(382),(383),(386),(387),(388),(389),(390),(393),(394),(400),
			(228), (229),
			(220),
			--Cricket
			(9404),(9405),(9406),(9407),(9408),(9409),(9410),(9411),(9412),(9413),(9414),(9415),
			(9416),(9417),(9418),(9419),(9420),(9421),(9422),(9423),(9428),(9429),(9430),(9431),
			(9432),(9433),(9496),(9497),(9498),(9499),(9500),(9501),(9502),(9503),(9504),(9505),
			(9506),(9507),(9508),(9509),(9510),(9511),(9512),(9513),(9514),(9515),(9516),(9517),
			(9518),(9519),
			(9446),(9447),(9449),(9450),(9452),(9453),(9454),(9455),(9460),(9461),(9527),(9528),
			(9530),(9532),(9533),(9604),(9605),(9607),(9608),(9609),(9610),(9611),(9612),(9613),(9614),
			(9089),(9090),(9091),(9092),(9093),(9094),(9095),(9096),(9097),(9098),(9099),(9100),(9116),(9117),(9118),(9119),(9120),(9121),(9123),(9126),(9127),(9128),(9129),(9131),(9134),(9136),(9137),(9139),(9140),
			(9616),(9617),(9618),(9619),(9620),(9621),(9622),(9623),(9676),(9677),(9678),(9679),(9680),(9681),(9682),(9683),(9684),(9685),(9686),(9687),(9688),(9689),(9690),(9691),(9692),(9693),(9694),(9695),(9708),(9709),(9730),(9731),(9732),(9733),(9734),(9735),(9736),(9737),(9738),(9739),(9696),(9697),(9698),(9699),(9702),(9703),(9704),(9705),
			(9448),(9451),(9456),(9457),(9458),(9459),(9462),(9463),(9464),(9465),(9529),(9531),(9534),(9535),(9536),(9537),
			--Volleyball AIO
			(3902),(3904),(3905),(3906),(3907),(3908),
			(219)
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
			(9001),(9006),(9007),(9011),(9015),(9016),(9017),(9021),(9022),(9023),(9027),(9031),(9032),(9033),(9037),(9038),(9039),(9043),(9044),(9045),(9049),(9050),(9051),(9055),(9056),(9057),(9062),(9063),(9064),(9068),(9072),(9073),(9069),(9075),(9087),
			(707),(712),(713),(714),
			(385),(630),
			-- Cricket
			(9400),(9401),
			(9434),(9435),(9436),(9437),(9438),(9439),(9442),(9443),
			(9101),(9102),(9103),(9104),(9105),(9106),(9107),(9108),(9109),(9110),(9111),(9112),(9113),(9114),(9115),(9122),(9124),(9125),(9130),(9132),(9133),(9135),(9138),(9141),(9142),	
			(9615),(9624),(9625),(9626),(9627),(9628),(9629),(9630),(9631),(9632),(9633),(9634),(9635),(9662),(9663),(9664),(9665),(9666),(9667),(9710),(9711),(9440),(9441),
			--Volleyball AIO
			(3901),(3903),(3909),(3912),(3914),(3916),(3918)
			
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
			(384),(391),(392),(395),(396),(397),(398),(399),
			(9088),
			(376),(618),(619),(620),(621),(622),(623),(624),(625),(626),(627),(628),(629),(631),(632),
			(633),(634),(635),(636),(637),(638),(639),(640),(641),(642),(643),(644),(645),(646),
			-- Basketball AIO
			(647),(648),(649),(650),
			-- Cricket
			(9490),(9491),
			(9636),(9637),(9638),(9639),(9640),(9641),(9650),(9651),(9652),(9653),(9654),(9655),(9656),(9657),(9658),(9659),(9660),(9661),(9668),(9669),(9670),(9671),(9672),(9673),(9674),(9675),
			--Volleyball AIO
			(3900),(3910),(3911),(3913),(3915),(3917)
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
		OR typeid BETWEEN 4001 AND 4100 -- Macau Games
		OR typeid BETWEEN 5800 AND 5999 -- Macau Games
		OR typeid BETWEEN 4101 AND 4300 -- PP
		OR typeid BETWEEN 6701 AND 7000 -- PP
		OR typeid BETWEEN 4301 AND 4600 -- SG
		OR typeid BETWEEN 5500 AND 5599 -- RNG War
		OR typeid BETWEEN 5601 AND 5699 -- ION
		OR typeid BETWEEN 6001 AND 6300 -- PG Soft
		OR typeid BETWEEN 6401 AND 6700 -- Joker
		OR typeid BETWEEN 2501 AND 2699
		OR typeid BETWEEN 2901 AND 2999
		OR typeid BETWEEN 1901 AND 1999
		OR typeid BETWEEN 3001 AND 3099
		OR typeID BETWEEN 3101 AND 3199
		OR TypeID BETWEEN 4901 AND 5000
		OR TypeID BETWEEN 3300 AND 3399
		OR TypeID BETWEEN 3201 AND 3299
		OR TypeID BETWEEN 5601 AND 5699
		OR typeid BETWEEN 3401 AND 3499 --WM
		OR typeid BETWEEN 5701 AND 5799 --GDG
		OR typeid BETWEEN 3501 AND 3599 --BG
		OR typeId BETWEEN 3701 AND 3799 --Pragmatic Live Casino 
		OR typeid BETWEEN 7901 AND 7999 -- Bitcoin product
		OR typeid BETWEEN 10300 AND 10399 -- WE Live Casino
		
) AS A

GO