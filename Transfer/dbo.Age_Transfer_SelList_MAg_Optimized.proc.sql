ALTER PROCEDURE [Age_Transfer_SelList_MAg_Optimized]
	@masterid as int,
	@Closed bit = 0
AS
--Vinh@20080102: add yesterday balance columns


select 	
	c.username, 
	c.custid,
	IsNull(credit.agentCredit, 0) AS agentCredit, 
	credit.agentUsedCredit, 
	IsNull(balance.agentOutstanding,0) AS agentOutstanding, 	
	
	IsNull(balance.agentCashBalance,0) AS agentCashBalance, 
	IsNull(balance.agentBalance + balance.agentCashBalance,0) agentBalance, 
	
	IsNull(balance.agentCashBalance,0) - IsNull(today_balance.agentCashBalance,0) AS yesterday_agentCashBalance, 
	IsNull(balance.agentBalance + balance.agentCashBalance,0) - IsNull(today_balance.agentBalance + today_balance.agentCashBalance, 0) yesterday_agentBalance,
	c.firstname, 
	c.lastname, 
	credit.agentClosedAccountCredit, 
	credit.accountCount
from
	(SELECT c.custid, c.username, c.firstname, c.lastname FROM customer AS c with (nolock) INNER JOIN custinfo as ci with (NOLOCK) on c.custid = ci.custid WHERE c.mrecommend = @masterid AND c.roleid = 2 and ci.closed = @closed) AS c
	INNER JOIN
	(
		SELECT c.recommend,
			isnull(SUM(CASE WHEN roleid = 2 THEN credit ELSE 0 END), 0) AS agentCredit,			
			isnull(SUM(CASE WHEN roleid = 1 THEN credit ELSE 0 END), 0) AS agentUsedCredit,
			isnull(SUM(CASE WHEN roleid = 1 AND closed = 1 THEN credit ELSE 0 END), 0) AS agentClosedAccountCredit,
			isnull(SUM(CASE WHEN roleid = 1 THEN 1 ELSE 0 END), 0) AS accountCount
		FROM custinfo as c (nolock)
		WHERE mrecommend = @masterid AND roleid < 3
		GROUP BY c.recommend
	) credit ON c.custid = credit.recommend
	LEFT OUTER JOIN
	(
		select 	recommend, 
			isnull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0) AS agentCashBalance, 
			isnull(sum(case when custid<>recommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) AS agentBalance, 
			isnull(sum(case when custid<>recommend and ruben=0 then apositiontaking*actual_stake else 0 end), 0) AS agentOutstanding 
		from bettrans with(nolock)
		where mrecommend = @masterid  
		group by recommend
	) balance ON c.custid = balance.recommend
	LEFT OUTER JOIN
	(
		select 	recommend, 
			isnull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0) AS agentCashBalance, 
			isnull(sum(case when custid<>recommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) AS agentBalance
		from bettrans with(nolock)
		where mrecommend = @masterid
		and bettrans.winlostdate >= convert(varchar(10), current_timestamp, 120)  
		group by recommend
	) today_balance ON c.custid = today_balance.recommend
order by c.username

GO

GRANT EXECUTE ON [Age_Transfer_SelList_MAg_Optimized] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [Age_Transfer_SelList_MAg_Optimized] TO [bodbDownlineNetView]
GO
