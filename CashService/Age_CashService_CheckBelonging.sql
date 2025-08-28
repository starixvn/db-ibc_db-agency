/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashService_CheckBelonging
(
	@CustID INT,
	@RoleID INT = 1, --RoleID of CustID
	@UplineId INT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
)
AS
/*
	Created: 20250821@Eden
	Task: Check Belonging 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250821@Eden: Alpha - Agency Cash Service - Sprint 9 [redmine: #236435] 

	Parameter's Explanation:	
	Sample:
		DECLARE @ErrCode INT = 0 ,@ErrMsg	VARCHAR(2000) = NULL
		EXEC Age_CashService_CheckBelonging
			@CustID	= 233657648 
			,@UplineID	= 228028013
			,@ErrCode = @ErrCode OUT 
			,@ErrMsg  = @ErrMsg OUT
		SELECT @ErrCode, @ErrMsg
*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @_roleid TINYINT

	SELECT @_roleid = ci.roleid
	FROM CustDB.dbo.vw_CashService_Customer ci WITH(NOLOCK)
	WHERE ci.custid = @custid
		AND ci.recommend = @UplineId

	-- #1 Check roleid
	IF @roleid <> @_roleid OR @_roleid IS NULL
	BEGIN
		SELECT @ErrCode = 415
			 , @ErrMsg = 'Invalid Member [' + ISNULL(CAST(@custid AS VARCHAR(10)),'') + ', ' + ISNULL(CAST(@UplineId AS VARCHAR(10)),'') + ']'
		RETURN
	END
END
GO