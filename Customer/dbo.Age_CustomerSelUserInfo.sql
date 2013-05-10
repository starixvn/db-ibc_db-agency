ALTER PROCEDURE [dbo].[Age_CustomerSelUserInfo]
	@custid int
AS
/*
Created: 20090211@nqminh
Updated: 20090227@Shifu
	-- get more customer information from custinfo
Task : Select customer information
DB: DB05.bodb02
Original:

Revisions:
    - 20090122@[Reviewer]: [Description of revision]    
    - 20090603@[Lee]: Add given credit info   
    - 20100901@[Henry]: Add SyncBingo
    - 20120202@Johnson: Add live casino
	- 20120726@Johnson: add bingo
Param's Explanation:
• @custid: custid that need to be viewed.   
*/

SET NOCOUNT ON

SELECT 
	Customer.custid,
	Customer.userpwd,
	ci.username,
	firstname, 
	lastname, 
	isnull(phone,'') as phone, 
	isnull(mobilephone,'') as mobilephone, 
	isnull(fax,'') as fax, 
	email,
	username2,
	ci.currency,  
	ci.closed, 
	ci.reject as suspend,
	ci.srecommend as superid,
	ci.mrecommend as masterid,
	ci.recommend as agentid, 
	Customer.roleid as roleid,
	ci.synccasino,
	ci.syncbingo,
	ci.disablecasino,
	ci.disablelivecasino,
	ci.DisableBingo,
	ci.synclivecasino,
	ci.credit,
	e.currency as currencyname
FROM Customer WITH (nolock)
	 INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.CustID --Shifu
	 INNER JOIN Exchange as e with (NOLOCK) ON Customer.currency = e.exchangeid   
	 
WHERE Customer.custid = @custid

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserInfo] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserInfo] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserInfo] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelUserInfo] TO vnteam