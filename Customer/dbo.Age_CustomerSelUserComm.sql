ALTER PROCEDURE [dbo].[Age_CustomerSelUserComm]
	@custid int,
	@userid int --upline id
AS
/*
Created: 20090211@nqminh
Task : Select customer commission
DB: DB05.bodb02
Original:

Revisions:
    - 20090122@[Reviewer]: [Description of revision]   
    - 20100924@Terry: Get discount for number game 

Param's Explanation:
• @custid: custid that need to be viewed.   
*/

SET NOCOUNT ON

DECLARE @ga decimal(9,8), @gb decimal(9,8), @gc decimal(9,8), @gd decimal(9,8), @dis decimal(9,8), @dis1x2 decimal(9,8),@disnumber decimal(9,8)
DECLARE @RoleId INT
SELECT @RoleId = RoleId
FROM CustInfo (nolock)
WHERE CustId = @CustId

IF (@RoleId = 1) 
BEGIN
	-- Member Commission --
	SELECT 	
		ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.discount ELSE 0 END), 0) AS discount,
		ISNULL(MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.discount ELSE 0 END), 0) AS discountcs,

		ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.playerdiscount ELSE 0 END), 0) AS playerdiscount,
		ISNULL(MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.playerdiscount ELSE 0 END), 0) AS playerdiscountcs,	
		
		ISNULL(MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.discount ELSE 0 END), 0) AS discount1x2,
		ISNULL(MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.playerdiscount ELSE 0 END), 0) AS playerdiscount1x2,
		
		ISNULL(MAX(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.discount ELSE 0 END), 0) AS discountnumber,
		ISNULL(MAX(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.playerdiscount ELSE 0 END), 0) AS playerdiscountnumber
	FROM 	
		CustSetting AS cs WITH (NOLOCK)
		Inner join CustSetting3rd as cs3 WITH (NOLOCK) on cs.custid = cs3.custid
	WHERE cs.custid=@custid
END
ELSE 
IF (@RoleId = 2) 
BEGIN
	-- Agent Commission ---	
	DECLARE @MRecommend INT
	SELECT @MRecommend = mrecommend FROM CustInfo (nolock) WHERE custid = @CustId	
	
	SELECT 
		@ga = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupa ELSE 0 END),
		@gb = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupb ELSE 0 END),
		@gc = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupc ELSE 0 END),
		@gd = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupd ELSE 0 END),
		@dis1x2 = MAX(CASE WHEN acs.bettype = 5 AND acs.sporttype=1 THEN acs.adiscount ELSE 0 END), --1x2 comm
		@dis = MAX(CASE WHEN acs.bettype = 4 AND acs.sporttype=1 THEN acs.adiscount ELSE 0 END), --other comm	
		@disnumber = MAX(CASE WHEN acs3.bettype = 81 AND acs3.sporttype=161 THEN acs3.adiscount ELSE 0 END)
			
	FROM custsetting as acs WITH (NOLOCK)
	INNER JOIN Custsetting3rd as acs3 WITH (NOLOCK) ON acs.custid = acs3.custid
	WHERE acs.custid = @MRecommend

	SELECT
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupa ELSE 0 END) AS groupa,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupb ELSE 0 END) AS groupb,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupc ELSE 0 END) AS groupc,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupd ELSE 0 END) AS groupd,
		MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.discount ELSE 0 END) AS discount1x2, --1x2 comm
		MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.discount ELSE 0 END) AS discountcs, --other comm		
		MAX(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.discount ELSE 0 END) AS discountnumber,
		@ga AS groupa_max,
		@gb AS groupb_max,
		@gc AS groupc_max,
		@gd AS groupd_max,
		@dis1x2 AS discount1x2_max,
		@dis AS discountcs_max,
		@disnumber as discountnumber_max		
	FROM 
		custsetting AS cs WITH (NOLOCK)
		INNER JOIN custsetting3rd as cs3 WITH (NOLOCK) ON cs.custid = cs3.custid
	WHERE 
		cs.custid=@CustID
END
ELSE
IF (@RoleId = 3) 
BEGIN
	-- Master Commission ---
	DECLARE @SRecommend INT
	SELECT @SRecommend = srecommend FROM CustInfo (nolock) WHERE custid = @CustId	
	
	SELECT 
		@ga = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupa ELSE 0 END),
		@gb = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupb ELSE 0 END),
		@gc = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupc ELSE 0 END),
		@gd = MAX(CASE WHEN acs.bettype = 1 AND acs.sporttype=1 THEN acs.groupd ELSE 0 END),
		@dis1x2 = MAX(CASE WHEN acs.bettype = 5 AND acs.sporttype=1 THEN acs.sdiscount ELSE 0 END), --1x2 comm
		@dis = MAX(CASE WHEN acs.bettype = 4 AND acs.sporttype=1 THEN acs.sdiscount ELSE 0 END), --other comm		
		@disnumber = MAX(CASE WHEN acs3.bettype = 81 AND acs3.sporttype=161 THEN acs3.sdiscount ELSE 0 END)
	FROM custsetting as acs WITH (NOLOCK)
	INNER JOIN CustSetting3rd as acs3 WITH (NOLOCK) ON acs.custid = acs3.custid
	WHERE acs.custid = @SRecommend
	
	SELECT
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupa ELSE 0 END) AS groupa,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupb ELSE 0 END) AS groupb,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupc ELSE 0 END) AS groupc,
		MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 THEN cs.groupd ELSE 0 END) AS groupd,
		MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.adiscount ELSE 0 END) AS discount1x2, --1x2 comm
		MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.adiscount ELSE 0 END) AS discountcs, --other comm	
		MAX(CASE WHEN cs3.bettype = 81 AND cs3.sporttype=161 THEN cs3.adiscount ELSE 0 END) AS discountnumber,	
		@ga AS groupa_max,
		@gb AS groupb_max,
		@gc AS groupc_max,
		@gd AS groupd_max,
		@dis1x2 AS discount1x2_max,
		@dis AS discountcs_max,
		@disnumber AS discountnumber_max
				
	FROM 
		custsetting AS cs WITH (NOLOCK)
		INNER JOIN CustSetting3rd as cs3 WITH (NOLOCK) ON cs.custid = cs3.custid
	WHERE 
		cs.custid=@CustID
END

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserComm] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserComm] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelUserComm]  TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelUserComm] TO [vnteam]