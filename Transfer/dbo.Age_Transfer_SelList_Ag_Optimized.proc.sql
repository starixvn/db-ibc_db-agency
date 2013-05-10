ALTER PROCEDURE [Age_Transfer_SelList_Ag_Oprimized1]
	@custid INT,
	@closed bit = 0
AS
SET NOCOUNT ON
--Remove custaccount
--UPDATED 03/20/2006: split table Customer
--Vinh@20080102: add yesterday balance columns

create table #bal
(
	winlostdate smalldatetime,
	custid int,
	outstanding money,
	oustxn money,
	balance money
)
CREATE CLUSTERED INDEX ind_temp ON #bal(custid)

insert into #bal
SELECT 
	winlostdate,
	custid,
	CASE WHEN ruben=0 THEN winlost-actual_stake END outstanding,
	CASE comstatus WHEN 's' THEN actual_stake ELSE 0 END oustxn,
	isnull(CASE WHEN ruben=1 THEN winlost-actual_stake+playercomm END, 0) balance
FROM bettrans WITH (NOLOCK)
where recommend = @custid

select  
	username,
	balance.custid,
	closed,
	firstname,
	lastname,
	isnull(outstanding, 0) outstanding,
	isnull(oustxn, 0) oustxn,
	isnull(balance.balance, 0) balance,
	isnull(balance.balance, 0) - isnull(today_balance.balance, 0) yesterday_balance,
	credit,
	member_recommend,
	member_mrecommend,
	agent_recommend,
	agent_mrecommend
from
(
	SELECT 
		c.username,
		c.custid,
		c.closed,
		c.firstname,
		c.lastname,
		SUM(outstanding) outstanding,
		SUM(oustxn) oustxn,
		SUM(b.balance) balance,
		c.credit AS credit,
		member_recommend,
		member_mrecommend,
		@CustID as agent_recommend,
		(select mrecommend from customer with (NOLOCK) where CustID = @CustID) as agent_mrecommend
	FROM 
	(	
		SELECT 
			customer.custid, 
			customer.username, 
			ci.closed, 
			customer.firstname, 
			customer.lastname,
			ci.credit,
			@custid as member_recommend,
			customer.mrecommend as member_mrecommend
		FROM 
			customer WITH (NOLOCK)
			INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.custid
		WHERE 
			customer.recommend = @custid AND
			ci.closed=@closed AND
			customer.roleid = 1

	) AS c 
	LEFT JOIN #bal as b WITH (NOLOCK) ON c.custid = b.custid
	GROUP BY c.custid, c.username, c.closed, c.firstname, c.lastname, c.credit, member_recommend, member_mrecommend
) balance 
LEFT JOIN
(
	SELECT 
		custid,
		SUM(balance) balance
	FROM #bal as b WITH (NOLOCK)
	WHERE b.winlostdate >= convert(varchar(10), current_timestamp, 120)
	GROUP BY custid
) today_balance ON balance.custid = today_balance.custid
ORDER BY closed, username
GO

GRANT EXECUTE ON [Age_Transfer_SelList_Ag_Oprimized1] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [Age_Transfer_SelList_Ag_Oprimized1] TO [bodbDownlineNetView]
