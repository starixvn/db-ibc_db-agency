ALTER PROCEDURE [dbo].[Age_CustomerSelUserInfo]
	@custid int
AS
BEGIN
/*
Created: 20090211@nqminh
Updated: 20090227@Shifu
	-- get more customer information from custinfo
Task : Select customer information
DB: DBCUST.CustDB
Original:

Revisions:
	- 20090122@[Reviewer]: [Description of revision]    
	- 20090603@[Lee]: Add given credit info   
	- 20100901@[Henry]: Add SyncBingo
	- 20120202@Johnson: Add live casino
	- 20120726@Johnson: add bingo
	- 20140520@Logan:   1.Retrieve remark for SAg, MAg, Ag from CustSuper, CustMaster & CustAgent
						2.Code aligning
	- 20150420@Elodie: Add Gold Deluxe Product
	- 20150610@Kos: Separate CustDB to DBCUST server (Move SP to DBCUST.CustDB)
	- 20150825@Helen: Colossus Bet - [Redmine: #41264]
	- 20151028@Helen: Member Information to support Muay Thai  [Redmine: #45496]

Param's Explanation:
• @custid: custid that need to be viewed.   
*/

	SET NOCOUNT ON

	declare @roleid tinyint
	declare @remark nvarchar(300) = ''
	select @roleid = roleid
	  from Customer with(nolock)
	 where custid = @custid
	 
	if @roleid = 1
	begin
		select @remark = remark
		  from customer with(nolock)
		 where custid = @custid
	end
	if @roleid = 2
	begin
		select @remark = creationRemark
		  from CustAgent with(nolock)
		 where custid = @custid
	end
	if @roleid = 3
	begin
		select @remark = creationRemark
		  from CustMaster with(nolock)
		 where custid = @custid
	end
	if @roleid = 4
	begin
		select @remark = creationRemark
		  from CustSuper with(nolock)
		 where custid = @custid
	end

	-- For MuayThai
	DECLARE @bitmapOrder INT 
	SET @bitmapOrder = (SELECT bitmapOrder FROM ProductStatusProfile WITH (NOLOCK) WHERE Sporttype = 44 AND Bettype = 3)

	SELECT Customer.custid,
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
		   ISNULL(ci.DisableGoldDeluxe,1) AS DisableGoldDeluxe,
		   ISNULL(ci.HideGoldDeluxe,1) AS HideGoldDeluxe,
		   
		   ISNULL(ci.DisableColossusBet,1) AS DisableColossusBet,
		   ISNULL(ci.HideColossusBet,1) AS HideColossusBet,
		   
		   -- For MuayThai
		   ISNULL(dbo.f_GetProductStatus(cps.bitmapIsDisabled, @bitmapOrder),0)  AS DisableMuayThai,
		   ISNULL(dbo.f_GetProductStatus(cps.bitmapIsHidden, @bitmapOrder),0) AS HideMuayThai,
		
		   ci.credit,
		   e.currency as currencyname,
		   @remark as remark
	  FROM Customer WITH(nolock) 
		 INNER JOIN CustInfo as ci with(NOLOCK)
				 on Customer.CustID = ci.CustID --Shifu
		 INNER JOIN Exchange as e with (NOLOCK)
				 ON Customer.currency = e.exchangeid
		 LEFT JOIN CustProductStatus cps WITH (NOLOCK) ON cps.CustID = ci.custid		 
		 
	 WHERE Customer.custid = @custid

	
END
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