ALTER PROCEDURE [Age_Rpt_CommByBettype_MAg]
	@CustID INT, 
	@FromDate SMALLDATETIME,
	@ToDate SMALLDATETIME,
	@MoveBetsDay datetime 
AS

/*
Created: 
Task : select commission by bet type
DB: DBAGE/bodb02
Original:

Revisions:
    - 20090225@Tuan: For Casino   
    - 20090317@Hanh: remove Finance 
    - 20090329@Phuc: not include finance transactions
    - 20090602@Kiwi: Not include HR (Fixed Odds).
    - 20100818@Henry: Allow to show 1st Half Money Line comm
    - 20100904@Kiwi: Get data for NumberGame and IBCBet Bingo
    - 20110516@Johnson: Apply new arrange bettype
    - 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
    - 20110824@Lukas: Add new bettypes: 13,24,25,26,27,28
    - 20110907@Tom: Add new bettypes 30
				apply new bet type 1st correct score on Sport Books	    
	- 20110928@Tom: 1. Edit Report for P2P Games (Bettype: 72->1000)
					2. Remove column NG (Bettype=22) on Report
	- 20111130@Sophia: Add new bettypes 124, 125 for 1x2HDP
	- 20120112@Sophia: Add LiveCasino: bettype: 1101 -> 1199
	- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
	- 20121010@Johnson: Add other bettypes for tennis (from 1301 to 1334)
	- 20130404@Lukas: remove HT.1x2 & FT.1x2 out from commission group 2
	- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
	- 20140417@Dom: Add new bettype 126, 127
	- 20140616@Dom: Support BetRadar [Redmine: #17148]
	- 20140826@Dom: Move bettype 24,26 to commission3 [Redmine: #20771]
	- 20140929@Sophia: Remove detail comm columns and calculate Sporting solution into TotalComm_1, TotalComm_3 [Redmine: #22640]
	- 20150326@Elodie: Move some bettypes to commission1 [Redmine: #32993]
	- 20150407@Cody: Apply sport bettype matrix [Redmine: #30169]
	- 20150407@Cody: Apply 60 New Bettypes - BetRadar Phase II [Redmine: #32734]
	- 20150511@Sophia: Apply Gold Deluxe and Metric Gaming [Redmine: #35278]
*/

SET NOCOUNT ON

DECLARE @FDate SMALLDATETIME
DECLARE @TDate SMALLDATETIME

CREATE TABLE #tmp(ma_comm money, bettype int, recommend int)

DECLARE @SportBettype TABLE(
			ProductID INT
			,Bettype INT
			,EventType INT
		)
		
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @FDate = DATEADD(day,1,@MoveBetsDay)
	ELSE
		SET @FDate = @FromDate

	INSERT INTO #tmp
	SELECT sum(isnull(acomm,0) - isnull(comm,0)) as ma_comm, b.bettype, recommend
	FROM dbo.bettrans b with(nolock) 
		INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	WHERE b.mrecommend = @CustID and ruben = 1 and
		winlostdate between @FDate and @ToDate 
		--and bettype < 19001  and bettype not in (31,32,33,41,42,43,51,52,53,54,55,56,61,62,63,64,65,66)
		--AND b.bettype NOT BETWEEN 1501 AND 1599 
		AND s.ProductID NOT IN(2, 8)
	GROUP BY recommend, b.bettype

	INSERT INTO #tmp
	SELECT sum(isnull(acomm,0) - isnull(comm,0)) as ma_comm, 1501, recommend
	FROM dbo.bettrans b with(nolock) 
		INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	WHERE b.mrecommend = @CustID and ruben = 1 and
		winlostdate between @FDate and @ToDate 
		--AND b.bettype BETWEEN 1501 AND 1599
		AND s.ProductID = 8
	GROUP BY recommend
END

IF @Fromdate <= @MoveBetsDay		
BEGIN
	IF @ToDate > @MoveBetsDay
		SET @TDate = @MoveBetsDay
	ELSE
		SET @TDate = @ToDate
		
	INSERT INTO #tmp
	SELECT sum(isnull(acomm,0) - isnull(comm,0)) as ma_comm, b.bettype, recommend
	FROM dbo.bettrans14 b with(nolock) 
		INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	WHERE b.mrecommend = @CustID and ruben = 1 and
		winlostdate between @FromDate and @TDate 
		--and bettype < 19001  and bettype not in (31,32,33,41,42,43,51,52,53,54,55,56,61,62,63,64,65,66)
		--AND b.bettype not BETWEEN 1501 AND 1599
		AND s.ProductID NOT IN(2, 8)
	GROUP BY recommend, b.bettype

	INSERT INTO #tmp
	SELECT sum(isnull(acomm,0) - isnull(comm,0)) as ma_comm, 1501, recommend
	FROM dbo.bettrans14 b with(nolock) 
		INNER JOIN @SportBettype s ON b.bettype = s.Bettype
	WHERE b.mrecommend = @CustID and ruben = 1 and
		winlostdate between @FromDate and @TDate 
		--AND b.bettype BETWEEN 1501 AND 1599
		AND s.ProductID = 8
	GROUP BY recommend
END
		
SELECT pvt.recommend, c.username, 
	
	isnull([1],0) + isnull([3],0) + isnull([7],0) + isnull([8],0) + isnull([2],0) + isnull([12],0) + isnull([13],0) + isnull([20],0) + isnull([21],0) + isnull([25],0) + isnull([27],0) + isnull([28],0) +
	isnull([121],0) + isnull([122],0) + isnull([123],0) + isnull([124],0) + isnull([125],0) +
	isnull([153],0) + isnull([154],0) + isnull([155],0) + isnull([156],0) + 
	isnull([1301],0) + isnull([1303],0) + isnull([1305],0) + isnull([1306],0) + isnull([1308],0) + isnull([1311],0) + isnull([1312],0) + isnull([1316],0) + isnull([1318],0) + isnull([1324],0) +
	ISNULL([157], 0) + ISNULL([178], 0) + ISNULL([183], 0) + ISNULL([184], 0) + ISNULL([185], 0) + ISNULL([189], 0) + ISNULL([190], 0) + ISNULL([191], 0) + ISNULL([194], 0) + ISNULL([197], 0) +
	ISNULL([198], 0) + ISNULL([203], 0) + ISNULL([204], 0) + ISNULL([205], 0) +
	ISNULL([801], 0) + ISNULL([802], 0) + ISNULL([803], 0) + ISNULL([804], 0) + ISNULL([805], 0) + ISNULL([806], 0) + ISNULL([807], 0) + ISNULL([808], 0) as totalcomm_1,

	
	isnull([5],0) + isnull([15],0) + ISNULL([167], 0) + ISNULL([176], 0) + ISNULL([177], 0) as [totalcomm_2],
		
	isnull([30],0) + isnull([4],0) + isnull([6],0) + isnull([126],0) + isnull([9],0) + isnull([10],0) + isnull([14],0) + isnull([127],0) + isnull([16],0) + isnull([29],0) +
	isnull([133],0) + isnull([134],0) + isnull([135],0) + isnull([145],0) + isnull([146],0) + isnull([147],0) + isnull([24],0) +  isnull([26],0) +
	isnull([148],0) + isnull([149],0) + isnull([150],0) + isnull([151],0) + isnull([152],0) + isnull([140],0) + isnull([141],0) + isnull([142],0) +
	isnull([1302],0) + isnull([1317],0) +
	
	ISNULL([159],0) + ISNULL([160],0) + ISNULL([161],0) + ISNULL([162],0) + ISNULL([163],0) + ISNULL([164],0) + ISNULL([165],0) + ISNULL([166],0) + ISNULL([168],0) + 
	ISNULL([169],0) + ISNULL([170],0) + ISNULL([171],0) + ISNULL([172],0) + ISNULL([173],0) + ISNULL([174],0) + ISNULL([175],0) + ISNULL([179],0) + ISNULL([180],0) + 
	ISNULL([181],0) + ISNULL([182],0) +	ISNULL([186],0) + ISNULL([187],0) + ISNULL([188],0) + ISNULL([192],0) + ISNULL([193],0) + ISNULL([195],0) + ISNULL([196],0) + 
	ISNULL([199],0) + ISNULL([200],0) + ISNULL([201],0) + ISNULL([202],0) +	ISNULL([206],0) + ISNULL([207],0) + ISNULL([208],0) + ISNULL([209],0) + ISNULL([210],0) + 
	ISNULL([211],0) + ISNULL([212],0) +	ISNULL([213],0) + ISNULL([214],0) + ISNULL([215],0) + ISNULL([216],0) + ISNULL([217],0) as totalcomm_3,
	
	---Casino_comm
	isnull([71],0) + 
	----LiveCasino_comm
	isnull([1101],0) + isnull([1102],0) + isnull([1103],0) + isnull([1104],0) + isnull([1105],0) + isnull([1106],0) + isnull([1107],0) + isnull([1108],0) + isnull([1109],0) + isnull([1110],0) +
	isnull([1111],0) + isnull([1112],0) + isnull([1113],0) + isnull([1114],0) + isnull([1115],0) + isnull([1116],0) + isnull([1117],0) + isnull([1118],0) + isnull([1119],0) + isnull([1120],0) + 
	isnull([1121],0) + isnull([1122],0) + isnull([1123],0) + isnull([1124],0) + isnull([1125],0) + isnull([1126],0) + isnull([1127],0) + isnull([1128],0) + isnull([1129],0) + isnull([1130],0) +
	isnull([1131],0) + isnull([1132],0) + isnull([1133],0) + isnull([1134],0) + isnull([1135],0) + isnull([1136],0) + isnull([1137],0) + isnull([1138],0) + isnull([1139],0) + isnull([1140],0) +
	isnull([1141],0) + isnull([1142],0) + isnull([1143],0) + isnull([1144],0) + isnull([1145],0) + isnull([1146],0) + isnull([1147],0) + isnull([1148],0) + isnull([1149],0) + isnull([1150],0) +
	---NumberGame_comm,
	isnull([81],0) + isnull([82],0) + isnull([83],0) + isnull([84],0) + isnull([85],0) + isnull([86],0) + isnull([87],0) + isnull([88],0) + isnull([89],0) + isnull([90],0) +
	isnull([91],0) + isnull([92],0) + isnull([93],0) + isnull([94],0) + isnull([95],0) + isnull([96],0) + isnull([97],0) + isnull([98],0) + isnull([99],0) + isnull([100],0) +
	isnull([101],0) + isnull([102],0) + isnull([103],0) + isnull([104],0) + isnull([105],0) + isnull([106],0) + isnull([107],0) + isnull([108],0) + isnull([109],0) + isnull([110],0)+ 
	isnull([111],0) + isnull([112],0) + isnull([113],0) + isnull([114],0) + isnull([115],0) + isnull([116],0) + isnull([117],0) + isnull([118],0) + isnull([119],0) + isnull([120],0)+
	---Bingo_comm
	isnull([73],0) +
	---Keno_comm
	ISNULL([1501],0) +
	---Gold Deluxe_Comm
	ISNULL([1701],0) + ISNULL([1702],0) + ISNULL([1703],0) AS Casino_comm
	
FROM #tmp AS p
PIVOT
(
	SUM(ma_comm)
	FOR bettype IN ([1],[3],[7],[8],[2],[12],[13],[4],[5],[15],[6],[9],[10],[14],[16],[20],[21],[24],[25],[26],[27],[28],[29],[30],[71],[73],
					[81],[82],[83],[84],[85],[86],[87],[88],[89],[90],[91],[92],[93],[94],[95],[96],[97],[98],[99],[100],
					[101],[102],[103],[104],[105],[106],[107],[108],[109],[110],[111],[112],[113],[114],[115],[116],[117],[118],[119],[120],
					[121],[122],[123],[124],[125],[126],[127],[1000],[1101],[1102],[1103],[1104],[1105],[1106],[1107],[1108],[1109],[1110],[1111],[1112],
					[133],[134],[135],[145],[146],[147],[148],[149],[150],[151],[152],[140],[141],[142],
					[801],[802],[803],[804],[805],[806],[807],[808],
					[1113],[1114],[1115],[1116],[1117],[1118],[1119],[1120],[1121],[1122],[1123],[1124],[1125],[1126],[1127],[1128],[1129],[1130],
					[1131],[1132],[1133],[1134],[1135],[1136],[1137],[1138],[1139],[1140],[1141],[1142],[1143],[1144],[1145],[1146],[1147],[1148],[1149],[1150],
					[1301],[1302],[1303],[1304],[1305],[1306],[1307],[1308],[1309],[1310],[1311],[1312],[1313],[1314],[1315],[1316],[1317],[1318],[1319],[1320],
					[1321],[1322],[1323],[1324],[1325],[1326],[1327],[1328],[1329],[1330],[1331],[1332],[1333],[1334],
					[153],[154],[155],[156],
					[1501],
					[1701],[1702],[1703],
					
					[157], [159], [160], [161], [162], [163], [164], [165], [166], [167], [168], [169], [170], [171], [172],
					[173], [174], [175], [176], [177], [178], [179], [180], [181], [182], [183], [184], [185], [186], [187], 
					[188], [189], [190], [191], [192], [193], [194], [195], [196], [197], [198], [199], [200], [201], [202], 
					[203], [204], [205], [206], [207], [208], [209], [210], [211], [212], [213], [214], [215], [216], [217]
					)  
) AS pvt
INNER JOIN customer c with(nolock) on c.custid = pvt.recommend 
ORDER BY c.username

DROP TABLE #tmp



GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_MAg] TO [vnteam]