ALTER PROCEDURE [Age_Transfer_SelList_SAg_Optimized]
	@SAgID int,
	@Closed bit = 0
AS
SET NOCOUNT ON
--Vinh@20080102: add yesterday balance columns



select 	c.username, 
	c.custid,
	IsNull(credit.magentCredit, 0) AS magentCredit, 
	credit.magentUsedCredit, 
	IsNull(balance.magentOutstanding,0) magentOutstanding, 
	IsNull(balance.magentCashBalance,0) magentCashBalance, 
	IsNull(balance.magentBalance + balance.magentCashBalance,0) magentBalance, 

	IsNull(balance.magentCashBalance,0) - IsNull(today_balance.magentCashBalance,0) yesterday_magentCashBalance, 
	IsNull(balance.magentBalance + balance.magentCashBalance,0) - IsNull(today_balance.magentBalance + today_balance.magentCashBalance,0) yesterday_magentBalance, 

	c.firstname, 
	c.lastname, 
	credit.magentClosedAccountCredit, 
	credit.accountCount 
from
(
	SELECT c.custid, c.username, c.firstname, c.lastname 
	FROM customer as c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid 
	WHERE c.srecommend = @SAgID AND c.roleid = 3 and ci.closed = @closed
) AS c
INNER JOIN
(
	SELECT 
		c.mrecommend,
		isnull(SUM(CASE WHEN roleid = 3 THEN credit ELSE 0 END), 0) AS magentCredit,
		isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS magentUsedCredit,
		isnull(SUM(CASE WHEN roleid = 1 AND closed = 1 THEN credit ELSE 0 END), 0) AS magentClosedAccountCredit,
		isnull(SUM(CASE WHEN roleid = 1 THEN 1 ELSE 0 END), 0) AS accountCount
	FROM custinfo as c (nolock)
	WHERE srecommend = @SAgID AND roleid < 4
	GROUP BY c.mrecommend
) AS credit ON c.custid = credit.mrecommend
LEFT OUTER JOIN
(
	select 	
		mrecommend, 
		isnull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end), 0) AS magentCashBalance, 
		isnull(sum(case when custid <> recommend and custid<>mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0)
			+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS magentBalance, 
		isnull(sum(case when custid<>mrecommend and ruben=0 then actual_stake*mpositiontaking else 0 end), 0) AS magentOutstanding 
	from bettrans with(nolock)
	where srecommend = @SAgID  
	group by mrecommend
) balance ON c.custid = balance.mrecommend
LEFT OUTER JOIN
(
	select 	
		mrecommend, 
		isnull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end), 0) AS magentCashBalance, 
		isnull(sum(case when custid <> recommend and custid<>mrecommend and custid <> srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0)
			+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end),0) AS magentBalance
	from bettrans with(nolock)
	where 
		srecommend = @SAgID 
		and bettrans.winlostdate >= convert(varchar(10), CURRENT_TIMESTAMP, 120)
	group by mrecommend
) today_balance ON c.custid = today_balance.mrecommend

order by c.username
GO
GRANT EXECUTE ON [Age_Transfer_SelList_SAg_Optimized] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [Age_Transfer_SelList_SAg_Optimized] TO [bodbDownlineNetView]
GO

