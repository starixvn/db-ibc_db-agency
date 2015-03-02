ALTER PROCEDURE [dbo].[Age_CustomerPermissionCheck]
	@SessionCustID int, --uplineID	
	@custid int = NULL,
	@SubAccountID INT = 0,
	@spPageAccess VARCHAR(50)='',	
	@isAllowedAccess BIT = 1 OUTPUT,	
	@isActive BIT = 1 OUTPUT,	
	@username VARCHAR(30) = '' OUTPUT,
	@roleid tinyint = 0 OUTPUT --0: not belonged to
AS
	/*
		Created: Johnson
		Date: 2015-03-02
		Task: Check permission of user on update actions
		DB: DBAGE/bodb02
		
		Revisions:
		
		Parameter's Explantion:
			- @SessionCustID: session of user do action
			- @subAccountID : sub-account id 
			- @spPageAccess: page need to check permission of sub-account on this
			- @isAllowedAccess: sub-account is allowed access or not on that page			
			- @isActive: check account is closed/disabled or not
	*/
BEGIN
	SET NOCOUNT ON 
	DECLARE @SessionRoleID TINYINT, @pageAccess VARCHAR(50)

	IF @SessionCustID IS NULL --Not check
	BEGIN
		SELECT @roleid = roleid
		FROM custinfo c WITH (NOLOCK)
		WHERE c.custid = @custid
		RETURN
	END
	
	SELECT	@SessionRoleID = roleid,
		@isActive = CASE WHEN closed = 1 OR Enabled = 0 THEN 0 ELSE 1 END
	FROM custinfo WITH(NOLOCK)
	WHERE custID = @SessionCustID
		
	IF ISNULL(@sessionRoleid ,0) = 0 RETURN
	
	SELECT	@roleid = roleid, @username = username		
	FROM custinfo c WITH (NOLOCK)
	WHERE c.custid = @custid
		AND
		(c.srecommend = @SessionCustID OR c.mrecommend = @SessionCustID
			OR c.recommend = @SessionCustID OR c.custid = @SessionCustID
			OR @SessionRoleID >= 5)
	
	IF @SubAccountID <> 0
	BEGIN
		SELECT @isActive = CASE WHEN closed = 0 THEN 1 ELSE 0 END ,
			@pageAccess = PageAccess
		FROM dbo.custSub WITH(NOLOCK) 
		WHERE subaccID = @SubAccountID AND custid = @SessionCustID
		
		IF ( CHARINDEX(@spPageAccess, @PageAccess) > 0 AND (@IsActive = 1) )
			SET @isAllowedAccess = 1
		ELSE 
			SET @isAllowedAccess = 0
	END
	
	
END
GO
GRANT EXECUTE ON [dbo].[Age_CustomerPermissionCheck] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerPermissionCheck] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerPermissionCheck] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerPermissionCheck] TO [bodbDownlineNetView]
