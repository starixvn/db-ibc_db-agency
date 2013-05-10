
ALTER PROCEDURE [dbo].[Age_CustomerSelBySAg_DELETED]
@SRecommend int
AS
--@Source Control
--Original: magentsite/account\customerlist.asp
--AGENT SITE
SET NOCOUNT ON



SELECT 
	ci.closed, 
	isnull(ci.reject,0) as suspended,
	m.username, 
	m.custid, 
	m.ugroup, 
	m.firstname, 
	m.lastname, 
	m.phone,
	m.mobilephone,
	m.iplogin as lastloginip,
	max(cs.groupa) as groupa, 
	max(cs.groupb) as groupb, 
	max(cs.groupc) as groupc, 
	max(cs.groupd) as groupd, 

	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.adiscount else 0 end) as discountcs,
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_3,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_4,
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_5,
	max(case when cs.bettype = 6 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_6,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_9,
	max(case when cs.bettype = 10 and cs.sporttype=1 then cs.spositiontaking else 0 end) as spositiontaking_10,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_8,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_3,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_4,
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_5,
	max(case when cs.bettype = 6 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_6,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_9,
	max(case when cs.bettype = 10 and cs.sporttype=1 then cs.mpositiontaking else 0 end) as mpositiontaking_10,

	--basketball
	max(case when cs.bettype = 1 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_9,
	max(case when cs.bettype = 20 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_9,
	max(case when cs.bettype = 20 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_20,
	
	-- football
	max(case when cs.bettype = 1 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_20,

	-- Tennis
	max(case when cs.bettype = 1 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_20,

	-- Baseball
	max(case when cs.bettype = 1 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_20,

	-- Golf
	max(case when cs.bettype = 1 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_20,

	-- Motosport
	max(case when cs.bettype = 1 and cs.sporttype=11 then cs.spositiontaking else 0 end) as v11spositiontaking_1,
	max(case when cs.bettype = 20 and cs.sporttype=11 then cs.spositiontaking else 0 end) as v11spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=11 then cs.mpositiontaking else 0 end) as v11mpositiontaking_1,
	max(case when cs.bettype = 20 and cs.sporttype=11 then cs.mpositiontaking else 0 end) as v11mpositiontaking_20,

	-- Financial
	max(case when cs.bettype = 2 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_2,
	max(case when cs.bettype = 21 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_21,
	max(case when cs.bettype = 22 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_22,

	max(case when cs.bettype = 2 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_2,
	max(case when cs.bettype = 21 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_21,
	max(case when cs.bettype = 22 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_22,

	-- Other sports
	max(case when cs.bettype = 1 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_20,

	e.exchangeid,
	e.currency,
	ci.matchlimit,
	ci.virtualmultiplier-1 as VirtualMultiplier
FROM 
	customer AS m with (NOLOCK)
	INNER JOIN custinfo as ci with (NOLOCK) on m.custid = ci.custid
	INNER JOIN CustSetting as cs with (NOLOCK) on m.custid = cs.custid
	INNER JOIN Exchange as e with (NOLOCK) on m.currency = e.exchangeid
WHERE m.SRecommend = @SRecommend and m.roleid=3
group by
	ci.closed, 
	ci.reject,
	m.username, 
	m.custid, 
	m.ugroup, 
	m.firstname, 
	m.lastname, 
	m.phone,
	m.mobilephone,
	m.iplogin,
	e.exchangeid,
	e.currency,
	ci.matchlimit,
	ci.virtualmultiplier
ORDER BY 
case when  isnull(ci.closed,0) = 1 then 2 when isnull(ci.reject,0) = 1 then 1 else 0 end,  
m.username

GO

GRANT EXECUTE ON [dbo].[Age_CustomerSelBySAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelBySAg] TO [bodbDownlineNetView]
GO

