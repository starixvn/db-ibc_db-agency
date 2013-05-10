/****** Object:  StoredProcedure [dbo].[Acc_CustomerSelByAg]    Script Date: 11/05/2007 11:35:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CustomerSelByAg_DELETED]
@Recommend int
AS
--@Source Control
--Original: agentsite/account\customerlist.asp
--AGENT SITE
--UPDATED 02/22/2006: remove refno
SET NOCOUNT ON




SELECT 
	ci.closed, isnull(ci.reject,0) as suspended, ci.virtualmultiplier-1 as VirtualMultiplier, m.username, m.custid, isnull(m.site,'') + m.ugroup as ugroup, IsNull(m.site,'') AS site, m.firstname, m.lastname, m.iplogin as lastloginip,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.discount else 0 end)*100 as discount,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.discount else 0 end)*100 as discountcs,
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.playerdiscount else 0 end)*100 as playerdiscount,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.playerdiscount else 0 end)*100 as playerdiscountcs,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_3,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_4,
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_5,
	max(case when cs.bettype = 6 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_6,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_9,
	max(case when cs.bettype = 10 and cs.sporttype=1 then cs.apositiontaking else 0 end) as apositiontaking_10,

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

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.alivepositiontaking else 0 end) as alivepositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.alivepositiontaking else 0 end) as alivepositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.alivepositiontaking else 0 end) as alivepositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.alivepositiontaking else 0 end) as alivepositiontaking_8,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.mlivepositiontaking else 0 end) as mlivepositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.mlivepositiontaking else 0 end) as mlivepositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.mlivepositiontaking else 0 end) as mlivepositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.mlivepositiontaking else 0 end) as mlivepositiontaking_8,

	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=1 then cs.slivepositiontaking else 0 end) as slivepositiontaking_8,

	--basketball
	max(case when cs.bettype = 1 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_9,
	max(case when cs.bettype = 20 and cs.sporttype=2 then cs.apositiontaking else 0 end) as v2apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_9,
	max(case when cs.bettype = 20 and cs.sporttype=2 then cs.mpositiontaking else 0 end) as v2mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_3,
	max(case when cs.bettype = 7 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_7,
	max(case when cs.bettype = 8 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_8,
	max(case when cs.bettype = 9 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_9,
	max(case when cs.bettype = 20 and cs.sporttype=2 then cs.spositiontaking else 0 end) as v2spositiontaking_20,

	--football
	max(case when cs.bettype = 1 and cs.sporttype=3 then cs.apositiontaking else 0 end) as v3apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=3 then cs.apositiontaking else 0 end) as v3apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=3 then cs.apositiontaking else 0 end) as v3apositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=3 then cs.apositiontaking else 0 end) as v3apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=3 then cs.mpositiontaking else 0 end) as v3mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=3 then cs.spositiontaking else 0 end) as v3spositiontaking_20,

	--tennis
	max(case when cs.bettype = 1 and cs.sporttype=5 then cs.apositiontaking else 0 end) as v5apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=5 then cs.apositiontaking else 0 end) as v5apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=5 then cs.apositiontaking else 0 end) as v5apositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=5 then cs.apositiontaking else 0 end) as v5apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=5 then cs.mpositiontaking else 0 end) as v5mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=5 then cs.spositiontaking else 0 end) as v5spositiontaking_20,

	--baseball
	max(case when cs.bettype = 1 and cs.sporttype=8 then cs.apositiontaking else 0 end) as v8apositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=8 then cs.apositiontaking else 0 end) as v8apositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=8 then cs.apositiontaking else 0 end) as v8apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=8 then cs.mpositiontaking else 0 end) as v8mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_1,
	max(case when cs.bettype = 3 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=8 then cs.spositiontaking else 0 end) as v8spositiontaking_20,

	--golf
	max(case when cs.bettype = 1 and cs.sporttype=10 then cs.apositiontaking else 0 end) as v10apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=10 then cs.apositiontaking else 0 end) as v10apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=10 then cs.apositiontaking else 0 end) as v10apositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=10 then cs.apositiontaking else 0 end) as v10apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=10 then cs.mpositiontaking else 0 end) as v10mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=10 then cs.spositiontaking else 0 end) as v10spositiontaking_20,

	--motosports
	max(case when cs.bettype = 1 and cs.sporttype=11 then cs.apositiontaking else 0 end) as v11apositiontaking_1,
	max(case when cs.bettype = 20 and cs.sporttype=11 then cs.apositiontaking else 0 end) as v11apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=11 then cs.mpositiontaking else 0 end) as v11mpositiontaking_1,
	max(case when cs.bettype = 20 and cs.sporttype=11 then cs.mpositiontaking else 0 end) as v11mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=11 then cs.spositiontaking else 0 end) as v11spositiontaking_1,
	max(case when cs.bettype = 20 and cs.sporttype=11 then cs.spositiontaking else 0 end) as v11spositiontaking_20,

	--Finance
	max(case when cs.bettype = 2 and cs.sporttype=12 then cs.apositiontaking else 0 end) as v12apositiontaking_2,
	max(case when cs.bettype = 21 and cs.sporttype=12 then cs.apositiontaking else 0 end) as v12apositiontaking_21,
	max(case when cs.bettype = 22 and cs.sporttype=12 then cs.apositiontaking else 0 end) as v12apositiontaking_22,

	max(case when cs.bettype = 2 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_2,
	max(case when cs.bettype = 21 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_21,
	max(case when cs.bettype = 22 and cs.sporttype=12 then cs.mpositiontaking else 0 end) as v12mpositiontaking_22,

	max(case when cs.bettype = 2 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_2,
	max(case when cs.bettype = 21 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_21,
	max(case when cs.bettype = 22 and cs.sporttype=12 then cs.spositiontaking else 0 end) as v12spositiontaking_22,

	--other sports
	max(case when cs.bettype = 1 and cs.sporttype=99 then cs.apositiontaking else 0 end) as v99apositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=99 then cs.apositiontaking else 0 end) as v99apositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=99 then cs.apositiontaking else 0 end) as v99apositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=99 then cs.apositiontaking else 0 end) as v99apositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=99 then cs.mpositiontaking else 0 end) as v99mpositiontaking_20,

	max(case when cs.bettype = 1 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_1,
	max(case when cs.bettype = 2 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_2,
	max(case when cs.bettype = 3 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_3,
	max(case when cs.bettype = 20 and cs.sporttype=99 then cs.spositiontaking else 0 end) as v99spositiontaking_20

FROM 
	customer AS m with (NOLOCK)
	INNER JOIN custinfo as ci with (NOLOCK) on m.custid = ci.custid
	INNER JOIN CustSetting as cs with (NOLOCK) on m.custid = cs.custid
WHERE 
	m.Recommend = @recommend and m.roleid=1 
GROUP BY
	ci.closed, ci.reject, ci.virtualmultiplier, m.username, m.custid, m.ugroup, m.site, m.firstname, m.lastname, m.iplogin
ORDER BY 
case when  isnull(ci.closed,0) = 1 then 2 when isnull(ci.reject,0) = 1 then 1 else 0 end, 
m.username
GO


GRANT EXECUTE ON [dbo].[Age_CustomerSelByAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelByAg] TO [bodbDownlineNetView]
GO

