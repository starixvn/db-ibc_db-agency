ALTER PROCEDURE [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging]
	@SessionCustID INT, --uplineID
	@CustID INT = NULL,
	@SubAccountID INT = 0,
	@IsActive BIT = 1 OUTPUT,
	@TransID BIGINT = NULL,
	@Username VARCHAR(30) = '' OUTPUT,
	@RoleID TINYINT = 0 OUTPUT --0: not belonged to
AS
/*
	Created: 20151110@Percy
	Task: Implement the change fOR Consoliated RepORt: check downline belonging FROM Consolidated Group [RedmineID: #47201]
	DB: DBAGE/bodb02
	ORiginal: Age_CustomerSelCheckBelonging
	
	Revisions:
	
*/
BEGIN

SET NOCOUNT ON
DECLARE @SessionRoleID TINYINT
DECLARE @UplineCustID INT
DECLARE @IsNotConsolidatedGroup SMALLINT = -1000
DECLARE @IsHeadline BIT

IF @SessionCustID IS NULL --Not check
BEGIN
	SELECT @roleid = roleid
	FROM custinfo c WITH (NOLOCK)
	WHERE c.custid = @custid
	RETURN
END

-- Check CustID by transid/refno --
IF @custid IS NULL
	SELECT @custid = custid FROM bodb02.dbo.bettrans WITH (NOLOCK) WHERE transid = @transid

IF @custid IS NULL
	SELECT @custid = custid FROM bodb02.dbo.bettrans14 WITH (NOLOCK) WHERE transid = @transid

IF @custid IS NULL
	SELECT @custid = custid FROM DBARC.bodb_archive.dbo.Bettrans_bk WITH (NOLOCK) WHERE transid = @transid
------------------------------------

-- Check SessionRoleID ------------
SELECT	@SessionRoleID = roleid,
		@IsActive = CASE WHEN closed = 1 OR Enabled = 0 THEN 0 ELSE 1 END
FROM custinfo WITH(NOLOCK)
WHERE custID = @SessionCustID

IF ISNULL(@sessionRoleid ,0) = 0 RETURN
-----------------------------------------

-- Check in line --------------------
SELECT	@RoleID = roleid, @Username = username		
FROM custinfo c WITH (NOLOCK)
WHERE c.custid = @custid
	AND
	(c.srecommend = @SessionCustID OR c.mrecommend = @SessionCustID
		OR c.recommend = @SessionCustID OR c.custid = @SessionCustID
		OR @SessionRoleID >= 5)

IF @SubAccountID <> 0
BEGIN
	SELECT @IsActive = CASE WHEN closed = 0 THEN 1 ELSE 0 END 
	FROM dbo.custSub WITH(NOLOCK) 
	WHERE subaccID = @SubAccountID AND custid = @SessionCustID
END

IF ISNULL(@RoleID, 0) <> 0 RETURN -- is inline --> don't check outline

-- Check Out line----------------------------------------------------------------
-- Check SessionCustID is Headline
SELECT @IsHeadline = (SELECT ISNULL(IsGroupHeadline, 0) FROM bodb02.dbo.custAccount WHERE custid = @SessionCustID)
---------------------------------

-- if is not headline, return failed

IF @IsHeadline = 1 -- is headline
-- Check CustID / Upline of CustID and SessionCustID are Consolidated Group or not --
BEGIN
	SELECT
		  @roleID = roleid
		, @Username = username
	FROM custinfo c WITH (NOLOCK) WHERE c.custid = @custid

	IF @roleID = 4 -- check CustID only
		SELECT @IsNotConsolidatedGroup = 
		(
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @SessionCustID
			EXCEPT
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @CustID
		)
	ELSE IF @roleID = 3 -- check CustID, srecommend
		SELECT @IsNotConsolidatedGroup =
		(
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @SessionCustID
			EXCEPT
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid IN (SELECT srecommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT @CustID)
		)
	ELSE IF @roleID = 2 -- check CustID, srecommend, mrecommend
		SELECT @IsNotConsolidatedGroup =
		(
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @SessionCustID
			EXCEPT
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid IN (SELECT srecommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT mrecommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT @CustID)
		)
	ELSE IF @roleID = 1 -- check CustID, srecommend, mrecommend, recommend
		SELECT @IsNotConsolidatedGroup =
		(
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @SessionCustID
			EXCEPT
			SELECT GroupID FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid IN (SELECT srecommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT mrecommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT recommend FROM custInfo WHERE custid = @CustID
																					  UNION
																					  SELECT @CustID)
		)
	----------------------------------------------------------------------------
END

IF @IsNotConsolidatedGroup IS NULL -- same group
	BEGIN
		SELECT @RoleID, @Username, @IsActive  -- roleID, Username of @CustID, IsActive of @SessionCustID
	END
ELSE -- not headline or not same group
	BEGIN
		SELECT @RoleID = 0
	END

END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging] TO [bodbExtAccNet]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging] TO [bodbDownlineNetView]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging] TO [bodbDownlineNet]
GO 
 GRANT EXECUTE ON [dbo].[Age_Rpt_CustomerConsolidatedGroup_CheckBelonging] TO [bodbAdminNet]
GO 
