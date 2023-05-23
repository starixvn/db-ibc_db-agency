/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Transfer_Credit_All_SelDownlineInfo]
	@CustId					INT,
	@DownlineUsername		NVARCHAR(50),
	@DownlineCustId			INT OUTPUT,
	@DownlineRoleId			TINYINT OUTPUT,
	@ErrCode				INT = 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000) = '' OUTPUT

AS

/*
	Created: 20230525@Danny
	DB: DBAGE.bodb02
	Task: Alpha - Transfer - Transfer All & Clear Credit - Select Downline Info (Super/Master only)

	Revisions:
		- 20230525@Danny: Initialize SP [RedmineID: #181595]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RoleId TINYINT, @srecommend INT, @n INT = 1
	SELECT  @RoleId = roleid, @srecommend = srecommend FROM dbo.Customer WITH (NOLOCK) WHERE custId = @CustId

	SELECT  @DownlineUsername = LTRIM(RTRIM(@DownlineUsername))
	
	-- get move bet date
	DECLARE @balanceUpDay SMALLDATETIME, @moveBetsDay SMALLDATETIME
	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @balanceUpDay = BalanceUpDay, @moveBetsDay = MoveBetsDay FROM @tblMoveBetBalanceUp

	IF @RoleId = 4
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	srecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1
	ELSE IF @RoleId = 3
		SELECT  @DownlineCustId = custId, @DownlineRoleId = roleId
		FROM	dbo.custInfo WITH (NOLOCK)
		WHERE	mrecommend = @CustId AND username = @DownlineUsername AND roleId = @RoleId - 1

	-- super/master only -- invalid downline
	IF @RoleId NOT IN (3,4) OR @DownlineCustId IS NULL
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'invalid downline'
		RETURN
	END

END
GO