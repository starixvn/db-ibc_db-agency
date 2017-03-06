USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Rpt_CommByBettype_Agent]
	@CustID			INT, 
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME 
AS

/*
	Created: 
	Task : Smartphone friendly - Win Loss Detail Report
	DB: DBAGE/bodb02
	Original SP: Age_Rpt_CommByBettype_MAg

	Revisions:
		- 20170213@Paul: Create new [RedmineID: #70629]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FDate SMALLDATETIME,
			@TDate SMALLDATETIME,
			@CID   INT;

	SELECT  @CID = @CustID;

	CREATE TABLE #tmp(
		ma_comm		MONEY,
		bettype		INT,
		recommend	INT
	);

	DECLARE @isTest BIT = 0;
	SELECT  @isTest = dbo.f_CheckSPVersion(@@PROCID);

	CREATE TABLE #SportBettype (ProductID INT, Bettype INT);

	INSERT INTO #SportBettype (ProductID, Bettype)
	SELECT ProductID, Bettype
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @isTest);

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @FDate = DATEADD(day,1,@MoveBetsDay);
		ELSE
			SET @FDate = @FromDate;

		INSERT INTO #tmp(ma_comm, bettype, recommend)
		SELECT  SUM(ISNULL(acomm,0) - ISNULL(comm,0)) AS ma_comm,
				CASE ProductID
					WHEN 6  THEN 71
					WHEN 8  THEN 1501
					WHEN 21 THEN 2401
					WHEN 22 THEN 4001
					WHEN 23 THEN 2502
					ELSE b.bettype END AS bettype,
				recommend
		FROM dbo.bettrans b WITH(NOLOCK) 
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
		WHERE b.mrecommend = @CustID 
			AND ruben = 1 
			AND winlostdate BETWEEN @FDate AND @ToDate 
			AND s.ProductID NOT IN(2,15)
		GROUP BY
			CASE ProductID
				WHEN 6  THEN 71
				WHEN 8  THEN 1501
				WHEN 21 THEN 2401
				WHEN 22 THEN 4001
				WHEN 23 THEN 2502
				ELSE b.bettype END,
			recommend;
	END

	IF @Fromdate <= @MoveBetsDay		
	BEGIN
		IF @ToDate > @MoveBetsDay
			SET @TDate = @MoveBetsDay;
		ELSE
			SET @TDate = @ToDate;
		
		INSERT INTO #tmp(ma_comm, bettype, recommend)
		SELECT  SUM(ISNULL(acomm,0) - ISNULL(comm,0)) AS ma_comm,
				CASE ProductID
					WHEN 6  THEN 71
					WHEN 8  THEN 1501
					WHEN 21 THEN 2401
					WHEN 22 THEN 4001
					WHEN 23 THEN 2502
					ELSE b.bettype END AS bettype,
				b.recommend
		FROM dbo.bettrans14 b with(nolock) 
			INNER JOIN #SportBettype s ON b.bettype = s.Bettype
			INNER JOIN (SELECT custid AS recommend FROM custInfo WITH (NOLOCK) WHERE mrecommend = @CID AND roleid = 2) r ON b.recommend = r.recommend -- to use faster index: recommend
		WHERE winlostdate BETWEEN @FromDate AND @TDate
			AND s.ProductID NOT IN(2,15)
		GROUP BY
			CASE ProductID
				WHEN 6  THEN 71
				WHEN 8  THEN 1501
				WHEN 21 THEN 2401
				WHEN 22 THEN 4001
				WHEN 23 THEN 2502
				ELSE b.bettype END,
			b.recommend;
	END
		
	SELECT	pvt.recommend AS CustId,
			c.username AS CustName, 
	
			ISNULL([1],0) + ISNULL([3],0) + ISNULL([7],0) + ISNULL([8],0) + ISNULL([2],0) + ISNULL([12],0) + ISNULL([13],0) + ISNULL([25],0) + ISNULL([27],0) + ISNULL([28],0) +
			ISNULL([121],0) + ISNULL([122],0) + ISNULL([123],0) + ISNULL([124],0) + ISNULL([125],0) +
			ISNULL([153],0) + ISNULL([155],0) + ISNULL([156],0) + 
			ISNULL([1303],0) + ISNULL([1305],0) + ISNULL([1306],0) + ISNULL([1308],0) + ISNULL([1312],0) + ISNULL([1316],0) + ISNULL([1318],0) +
			ISNULL([157], 0) + ISNULL([178], 0) + ISNULL([183], 0) + ISNULL([184], 0) + ISNULL([185], 0) + ISNULL([189], 0) + ISNULL([190], 0) + ISNULL([191], 0) + ISNULL([194], 0) + ISNULL([197], 0) +
			ISNULL([198], 0) + ISNULL([203], 0) + ISNULL([204], 0) + ISNULL([205], 0) +
			ISNULL([801], 0) + ISNULL([802], 0) + ISNULL([803], 0) + ISNULL([804], 0) + ISNULL([805], 0) + ISNULL([806], 0) + ISNULL([807], 0) + ISNULL([808], 0) +
			ISNULL([401],0) + ISNULL([402],0) + ISNULL([403],0) + ISNULL([404],0) + ISNULL([411],0) +
			ISNULL([428],0) + ISNULL([432],0) + ISNULL([434],0) + ISNULL([435],0) +
			ISNULL([17], 0) + ISNULL([18], 0) AS Comm1,
	
			ISNULL([5],0) + ISNULL([15],0) + ISNULL([167], 0) + ISNULL([176], 0) + ISNULL([177], 0) + ISNULL([20],0) + ISNULL([21],0) + ISNULL([154],0) +
			ISNULL([1301],0) + ISNULL([1311],0) + ISNULL([1324],0) + ISNULL([501],0) +
			ISNULL([430], 0) AS Comm2,
		
			ISNULL([30],0) + ISNULL([4],0) + ISNULL([6],0) + ISNULL([126],0) + ISNULL([9],0) + ISNULL([10],0) + ISNULL([14],0) + ISNULL([127],0) + ISNULL([16],0) + ISNULL([29],0) +
			ISNULL([133],0) + ISNULL([134],0) + ISNULL([135],0) + ISNULL([145],0) + ISNULL([146],0) + ISNULL([147],0) + ISNULL([24],0) +  ISNULL([26],0) +
			ISNULL([148],0) + ISNULL([149],0) + ISNULL([150],0) + ISNULL([151],0) + ISNULL([152],0) + ISNULL([140],0) + ISNULL([141],0) + ISNULL([142],0) +
			ISNULL([1302],0) + ISNULL([1317],0) +
	
			ISNULL([159],0) + ISNULL([160],0) + ISNULL([161],0) + ISNULL([162],0) + ISNULL([163],0) + ISNULL([164],0) + ISNULL([165],0) + ISNULL([166],0) + ISNULL([168],0) + 
			ISNULL([169],0) + ISNULL([170],0) + ISNULL([171],0) + ISNULL([172],0) + ISNULL([173],0) + ISNULL([174],0) + ISNULL([175],0) + ISNULL([179],0) + ISNULL([180],0) + 
			ISNULL([181],0) + ISNULL([182],0) +	ISNULL([186],0) + ISNULL([187],0) + ISNULL([188],0) + ISNULL([192],0) + ISNULL([193],0) + ISNULL([195],0) + ISNULL([196],0) + 
			ISNULL([199],0) + ISNULL([200],0) + ISNULL([201],0) + ISNULL([202],0) +	ISNULL([206],0) + ISNULL([207],0) + ISNULL([208],0) + ISNULL([209],0) + ISNULL([210],0) + 
			ISNULL([211],0) + ISNULL([212],0) +	ISNULL([213],0) + ISNULL([214],0) + ISNULL([215],0) + ISNULL([216],0) + ISNULL([217],0) +
			ISNULL([405],0) + ISNULL([406],0) + ISNULL([407],0) + ISNULL([408],0) + ISNULL([409],0) + ISNULL([410],0) + ISNULL([412],0) +
			ISNULL([415],0) + ISNULL([416],0) + ISNULL([427],0) + ISNULL([431],0) + ISNULL([433],0) + ISNULL([436],0) + ISNULL([437],0) +
			ISNULL([438],0) + ISNULL([439],0) + ISNULL([440],0) + ISNULL([441],0) + ISNULL([442],0) + ISNULL([443],0) + ISNULL([444],0) +
			ISNULL([417],0) + ISNULL([418],0) + ISNULL([419],0) + ISNULL([420],0) + ISNULL([421],0) + ISNULL([422],0) + ISNULL([423],0) +
			ISNULL([424],0) + ISNULL([425],0) + ISNULL([426],0) + ISNULL([429],0) + ISNULL([445],0) + ISNULL([446],0) + ISNULL([447],0) + 
			ISNULL([221],0) + ISNULL([222],0) + ISNULL([223],0) + ISNULL([224],0) + ISNULL([225],0) AS Comm3,
	
			---Casino_comm
			ISNULL([71],0) + 
			----LiveCasino_comm
			ISNULL([1101],0) + ISNULL([1102],0) + ISNULL([1103],0) + ISNULL([1104],0) + ISNULL([1105],0) + ISNULL([1106],0) + ISNULL([1107],0) + ISNULL([1108],0) + ISNULL([1109],0) + ISNULL([1110],0) +
			ISNULL([1111],0) + ISNULL([1112],0) + ISNULL([1113],0) + ISNULL([1114],0) + ISNULL([1115],0) + ISNULL([1116],0) + ISNULL([1117],0) + ISNULL([1118],0) + ISNULL([1119],0) + ISNULL([1120],0) + 
			ISNULL([1121],0) + ISNULL([1122],0) + ISNULL([1123],0) + ISNULL([1124],0) + ISNULL([1125],0) + ISNULL([1126],0) + ISNULL([1127],0) + ISNULL([1128],0) + ISNULL([1129],0) + ISNULL([1130],0) +
			ISNULL([1131],0) + ISNULL([1132],0) + ISNULL([1133],0) + ISNULL([1134],0) + ISNULL([1135],0) + ISNULL([1136],0) + ISNULL([1137],0) + ISNULL([1138],0) + ISNULL([1139],0) + ISNULL([1140],0) +
			ISNULL([1141],0) + ISNULL([1142],0) + ISNULL([1143],0) + ISNULL([1144],0) + ISNULL([1145],0) + ISNULL([1146],0) + ISNULL([1147],0) + ISNULL([1148],0) + ISNULL([1149],0) + ISNULL([1150],0) +
			---NumberGame_comm,
			ISNULL([81],0) + ISNULL([82],0) + ISNULL([83],0) + ISNULL([84],0) + ISNULL([85],0) + ISNULL([86],0) + ISNULL([87],0) + ISNULL([88],0) + ISNULL([89],0) + ISNULL([90],0) +
			ISNULL([91],0) + ISNULL([92],0) + ISNULL([93],0) + ISNULL([94],0) + ISNULL([95],0) + ISNULL([96],0) + ISNULL([97],0) + ISNULL([98],0) + ISNULL([99],0) + ISNULL([100],0) +
			ISNULL([101],0) + ISNULL([102],0) + ISNULL([103],0) + ISNULL([104],0) + ISNULL([105],0) + ISNULL([106],0) + ISNULL([107],0) + ISNULL([108],0) + ISNULL([109],0) + ISNULL([110],0)+ 
			ISNULL([111],0) + ISNULL([112],0) + ISNULL([113],0) + ISNULL([114],0) + ISNULL([115],0) + ISNULL([116],0) + ISNULL([117],0) + ISNULL([118],0) + ISNULL([119],0) + ISNULL([120],0)+
			---Bingo_comm
			ISNULL([73],0) +
			---Keno_comm
			ISNULL([1501],0) +
			---Gold Deluxe_Comm
			ISNULL([1701],0) + ISNULL([1702],0) + ISNULL([1703],0) +
			---AllBet
			ISNULL([2401],0) +
			---Voidbridge
			ISNULL([4001],0) +
			---NG2
			ISNULL([2502],0) AS CasinoComm,

			ISNULL([301],0) + ISNULL([302],0) + ISNULL([303],0) + ISNULL([304],0) AS MOComm,
			---Cock Fighting_Comm
			ISNULL([1003],0) AS OtherComm,
			---Charge_Comm
			ISNULL([500],0) AS ChargeComm
	
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
							[203], [204], [205], [206], [207], [208], [209], [210], [211], [212], [213], [214], [215], [216], [217],
							[301], [302], [303], [304],
							[401], [402], [403], [404], [405], [406], [407], [408], [409], [410], [411], [412],
							[1003],
							[500], [501],
							[2401],
							[4001],
							[415], [416], [427], [428], [430], [431], [432], [433], [434], [435], [436], [437], [438], [439], [440], [441], [442], [443], [444],
							[17], [18],
							[2502],
							[417], [418], [419], [420], [421], [422], [423], [424], [425], [426], [429], [445], [446], [447],
							[221], [222], [223], [224], [225]
							)  
		) AS pvt
		INNER JOIN customer c WITH(NOLOCK) On c.custid = pvt.recommend 
	ORDER BY c.username;

	DROP TABLE #tmp;
	DROP TABLE #SportBettype;

	SET NOCOUNT OFF;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [vnteam] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_Agent] TO [bodbDownlineNet] AS [dbo]
GO