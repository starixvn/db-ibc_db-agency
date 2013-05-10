

ALTER PROCEDURE [dbo].[Age_CustomerSelComm_MAg]
	@MRecommend int
AS

/*
Created: 
Task : Select member commission information
DB: DB053.bodb02
Original: CustomerSelCommByMAg
Revisions:
	- 20091204@Kiwi: Retrieve data from CustSetting3rd for Financials.
	- 20100603@Jamie: Fix getting 3rd commission
	- 20100904@Kiwi: Get NumberGame Commission.
	- 20110323@Lukas: Remove horse racing
	- 20120928@Sophia: Get DoubleCommLosing
*/

SET NOCOUNT ON
SELECT 
	ci.closed,ci.enabled, isnull(ci.reject,0) as suspended, m.username, m.custid, m.ugroup, 
	m.firstname, m.lastname, ci.credit, ci.DoubleCommLosing,
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.adiscount else 0 end)*100 as adiscount,
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.discount else 0 end)*100 as discount,
	max(case when cs.bettype = 1 and cs.sporttype=1 then cs.playerdiscount else 0 end)*100 as playerdiscount,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.adiscount else 0 end)*100 as adiscountcs,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.discount else 0 end)*100 as discountcs,
	max(case when cs.bettype = 4 and cs.sporttype=1 then cs.playerdiscount else 0 end)*100 as playerdiscountcs,

	--Get 1x2
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.adiscount else 0 end)*100 as adiscount1x2,
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.discount else 0 end)*100 as discount1x2,
	max(case when cs.bettype = 5 and cs.sporttype=1 then cs.playerdiscount else 0 end)*100 as playerdiscount1x2,

	--Get Horse Racing for Tote and Fixed odd
--	max(case when cs3rd.bettype = 31 and cs3rd.sporttype=151 then cs3rd.adiscount else 0 end)*100 adiscount_hr_to,
--	max(case when cs3rd.bettype = 31 and cs3rd.sporttype=151 then cs3rd.discount else 0 end)*100 discount_hr_to,
--	max(case when cs3rd.bettype = 31 and cs3rd.sporttype=151 then cs3rd.playerdiscount else 0 end)*100 playerdiscount_hr_to,	
--	
--	max(case when cs3rd.bettype = 41 and cs3rd.sporttype=151 then cs3rd.adiscount else 0 end)*100 adiscount_hr_fo,
--	max(case when cs3rd.bettype = 41 and cs3rd.sporttype=151 then cs3rd.discount else 0 end)*100 discount_hr_fo,
--	max(case when cs3rd.bettype = 41 and cs3rd.sporttype=151 then cs3rd.playerdiscount else 0 end)*100 playerdiscount_hr_fo,
--	
	--Get Financial commission 	
--	max(case when cs3rd.bettype = 3 and cs3rd.sporttype=201 then cs3rd.adiscount else 0 end)*100 adiscount_financial,
--	max(case when cs3rd.bettype = 3 and cs3rd.sporttype=201 then cs3rd.discount else 0 end)*100 discount_financial,
--	max(case when cs3rd.bettype = 3 and cs3rd.sporttype=201 then cs3rd.playerdiscount else 0 end)*100 playerdiscount_financial,
	
	--Get NumberGame commission 	
	max(case when cs3rd.bettype = 81 and cs3rd.sporttype=161 then cs3rd.adiscount else 0 end)*100 adiscount_numbergame,
	max(case when cs3rd.bettype = 81 and cs3rd.sporttype=161 then cs3rd.discount else 0 end)*100 discount_numbergame,
	max(case when cs3rd.bettype = 81 and cs3rd.sporttype=161 then cs3rd.playerdiscount else 0 end)*100 playerdiscount_numbergame
	--End
FROM 
	customer AS m with (NOLOCK)
	INNER JOIN CustInfo as ci with (NOLOCK) on m.CustID = ci.CustID
	INNER JOIN CustSetting as cs with (NOLOCK) on m.CustID = cs.CustID
	INNER JOIN CustSetting3rd as cs3rd with (NOLOCK) on m.custID = cs3rd.CustID
WHERE m.MRecommend = @MRecommend and m.roleid=1 
GROUP BY
	ci.enabled, ci.closed, ci.reject, m.username, m.custid, m.ugroup, 
	m.firstname, m.lastname, ci.credit, ci.DoubleCommLosing
ORDER BY 
case when isnull(ci.enabled,0) = 0 then 3 when isnull(ci.closed,0) = 1 then 2 when isnull(ci.reject,0) = 1 then 1 else 0 end, 
m.username



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelComm_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelComm_MAg] TO [bodbDownlineNetView]
Go
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelComm_MAg] TO [vnteam]
