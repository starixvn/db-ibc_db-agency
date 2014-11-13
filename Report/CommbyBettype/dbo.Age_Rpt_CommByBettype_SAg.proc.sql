ALTER PROCEDURE [Age_Rpt_CommByBettype_SAg]
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
    - 20110801@Sophia: change the range of number game's bettype from 81 to 120,  add new bettype 29 for Combination Mix parlay
	- 20110824@Lukas: Add new bettypes: 13,24,25,26,27,28
    - 20110907@Tom: Add new bettypes 30
				apply new bet type 1st correct score on Sport Books		
	- 20110928@Tom: 1. Edit Report for P2P Games (Bettype: 72->1000)
					2. Remove column NG(Bettype=22) on Report.
	- 20111130@Sophia: Add new bettypes 124, 125 for 1x2HDP
	- 20120112@Sophia: Add LiveCasino:  bettype: 1101 -> 1199
	- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
	- 20121010@Johnson: - Show short list commission types
						- Add other bettypes for tennis (from 1301 to 1334)
	- 20130404@Lukas: remove HT.1x2 & FT.1x2 out from commission group 2
	- 20140303@Kathy: Apply Keno product (from 1501 -> 1599)[Redmine:#12691]
	- 20140616@Dom: Support BetRadar [Redmine: #17148]
	- 20140826@Dom: Move bettype 24,26 to commission3 [Redmine: #20771]
	- 20140929@Sophia: Remove detail comm columns and calculate Sporting solution into TotalComm_1, TotalComm_3 [Redmine: #22640]
*/

SET NOCOUNT ON

DECLARE @FDate SMALLDATETIME
DECLARE @TDate SMALLDATETIME

CREATE TABLE #tmp(sa_comm money, bettype int, mrecommend int)

IF @Todate > @MoveBetsDay
BEGIN
	IF @FromDate <= @MoveBetsDay
		SET @FDate = DATEADD(day,1,@MoveBetsDay)
	ELSE
		SET @FDate = @FromDate

	INSERT INTO #tmp
	SELECT sum(isnull(scomm,0) - isnull(acomm,0)) as sa_comm, bettype, mrecommend
	FROM dbo.bettrans b with(nolock) 
	WHERE b.srecommend = @CustID and ruben = 1 and
		winlostdate between @FDate and @ToDate 
		and bettype < 19001  and bettype not in (31,32,33,41,42,43,51,52,53,54,55,56,61,62,63,64,65,66)
		AND b.bettype NOT BETWEEN 1501 AND 1599 
	GROUP BY mrecommend,bettype	

	INSERT INTO #tmp
	SELECT sum(isnull(scomm,0) - isnull(acomm,0)) as sa_comm, 1501, mrecommend
	FROM dbo.bettrans b with(nolock) 
	WHERE b.srecommend = @CustID and ruben = 1 and
		winlostdate between @FDate and @ToDate 
		AND b.bettype BETWEEN 1501 AND 1599 
	GROUP BY mrecommend
END

IF @Fromdate <= @MoveBetsDay		
BEGIN
	IF @ToDate > @MoveBetsDay
		SET @TDate = @MoveBetsDay
	ELSE
		SET @TDate = @ToDate

	INSERT INTO #tmp
	SELECT sum(isnull(scomm,0) - isnull(acomm,0)) as sa_comm, bettype, mrecommend
	FROM dbo.bettrans14 b with(nolock) 
	WHERE b.srecommend = @CustID and ruben = 1 and
		winlostdate between @FromDate and @TDate 
		and bettype < 19001  and bettype not in (31,32,33,41,42,43,51,52,53,54,55,56,61,62,63,64,65,66)
		AND b.bettype BETWEEN 1501 AND 1599 
	GROUP BY mrecommend,bettype

	INSERT INTO #tmp
	SELECT sum(isnull(scomm,0) - isnull(acomm,0)) as sa_comm, 1501, mrecommend
	FROM dbo.bettrans14 b with(nolock) 
	WHERE b.srecommend = @CustID and ruben = 1 and
		winlostdate between @FromDate and @TDate 
		AND b.bettype BETWEEN 1501 AND 1599 
	GROUP BY mrecommend
END

SELECT pvt.mrecommend, c.username, 
	
	isnull([1],0) + isnull([3],0) + isnull([7],0) + isnull([8],0) + isnull([2],0) + isnull([12],0) + isnull([13],0) + isnull([25],0) + isnull([27],0) + isnull([28],0) +
	isnull([121],0) + isnull([122],0) + isnull([123],0) + isnull([124],0) + isnull([125],0) +
	isnull([153],0) + isnull([155],0) + isnull([156],0) + isnull([1303],0) + isnull([1305],0) + isnull([1306],0) + isnull([1308],0) + isnull([1312],0) + isnull([1316],0) + isnull([1318],0) as totalcomm_1,

	
	isnull([5],0) + isnull([15],0) as [totalcomm_2],
	
	isnull([30],0) + isnull([4],0) + isnull([6],0) + isnull([126],0) + isnull([9],0) + isnull([10],0) + isnull([14],0) + isnull([127],0) + isnull([16],0) + isnull([20],0) + isnull([29],0) +
	isnull([133],0) + isnull([134],0) + isnull([135],0) + isnull([145],0) + isnull([146],0) + isnull([147],0) + isnull([24],0) + isnull([26],0) +
	isnull([148],0) + isnull([149],0) + isnull([150],0) + isnull([151],0) + isnull([152],0) + isnull([140],0) + isnull([141],0) + isnull([142],0) +
	isnull([154],0) + isnull([1301],0) + isnull([1302],0) + isnull([1311],0) + isnull([1317],0) + isnull([1324],0) as totalcomm_3,
		
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
	ISNULL([1501],0) as Casino_comm

FROM #tmp AS p
PIVOT
(
	SUM(sa_comm)
	FOR bettype IN ([1],[3],[7],[8],[2],[12],[13],[4],[5],[15],[6],[9],[10],[14],[16],[20],[21],[24],[25],[26],[27],[28],[29],[30],[71],[73],
					[81],[82],[83],[84],[85],[86],[87],[88],[89],[90],[91],[92],[93],[94],[95],[96],[97],[98],[99],[100],
					[101],[102],[103],[104],[105],[106],[107],[108],[109],[110],[111],[112],[113],[114],[115],[116],[117],[118],[119],[120],
					[121],[122],[123],[124],[125],[126],[127],[1000],[1101],[1102],[1103],[1104],[1105],[1106],[1107],[1108],[1109],[1110],[1111],[1112],
					[133],[134],[135],[145],[146],[147],[148],[149],[150],[151],[152],[140],[141],[142],
					[1113],[1114],[1115],[1116],[1117],[1118],[1119],[1120],[1121],[1122],[1123],[1124],[1125],[1126],[1127],[1128],[1129],[1130],
					[1131],[1132],[1133],[1134],[1135],[1136],[1137],[1138],[1139],[1140],[1141],[1142],[1143],[1144],[1145],[1146],[1147],[1148],[1149],[1150],
					[1301],[1302],[1303],[1304],[1305],[1306],[1307],[1308],[1309],[1310],[1311],[1312],[1313],[1314],[1315],[1316],[1317],[1318],[1319],[1320],					
					[1321],[1322],[1323],[1324],[1325],[1326],[1327],[1328],[1329],[1330],[1331],[1332],[1333],[1334],
					[153],[154],[155],[156],
					[1501]
					)
) AS pvt
INNER JOIN customer c with(nolock) on c.custid = pvt.mrecommend 
ORDER BY c.username
 
DROP TABLE #tmp



GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_CommByBettype_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CommByBettype_SAg] TO [vnteam]