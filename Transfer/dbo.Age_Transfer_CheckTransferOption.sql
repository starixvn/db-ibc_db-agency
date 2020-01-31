/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="1"></info>*/

ALTER PROCEDURE [dbo].[Age_Transfer_CheckTransferOption]
	@CustID				INT,
	@Language			VARCHAR(2) = 'E',
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(400) = '' OUTPUT,
	@strTransferOption	VARCHAR(8) = NULL OUTPUT
AS

/*
	Created by: []
	DB: DBCUST.CustDB
	Task:
	
	Revisions:
		- 20100413@Kiwi: Get transferoption from CustSuper/CustMaster/CustAgent
		- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
		- 20180801@Percy: Output @strTransferOption param [RedmineID: #92142]
		- 20190131@Elodie: Change time GMT-4 [RedmineID: #127649]

	----------------------------------------------------------------------
	--	Check Transfer Condition (for master and agent)
		1		2		3		4		5		6		7		8
		isSun	isMon	isTue	isWed	isThurs	isFri	isSat	isWeekly
		0		1		0		0		1		0		1		1
	----------------------------------------------------------------------

*/
BEGIN
	SELECT @ErrCode = 0, @ErrMsg = ''

	-- Skip checking for direct master
	IF EXISTS (SELECT 1 FROM dbo.customer WITH (NOLOCK) WHERE custid = @custid AND roleid = 3 AND srecommEND < 100)
		RETURN

	DECLARE @RoleID TINYINT
	SELECT @RoleID = RoleID FROM custinfo WITH (NOLOCK) WHERE custid = @CustId

	IF (@RoleID = 4)
	BEGIN 
		SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
		FROM dbo.CustSuper WITH (NOLOCK) 
		WHERE custid = @CustId
	END
	ELSE IF (@RoleID = 3)
	BEGIN 
		SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
		FROM dbo.CustMaster WITH (NOLOCK) 
		WHERE custid = @CustId
	END
	ELSE IF (@RoleID = 2)
	BEGIN 
		SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
		FROM dbo.CustAgent WITH (NOLOCK) 
		WHERE custid = @CustId
	END

	IF SUBSTRING(@strTransferOption, 8, 1) = 1 --isWeekly = 1
		AND SUBSTRING(@strTransferOption, DATEPART(WEEKDAY, CURRENT_TIMESTAMP), 1) = 0
	BEGIN	
		SELECT @ErrMsg = CASE @Language 
							WHEN 'E' THEN 'Sorry, you can only transfer on: ' +
								CASE WHEN SUBSTRING(@strTransferOption, 2, 1) = 1 THEN 'Monday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 3, 1) = 1 THEN 'Tuesday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 4, 1) = 1 THEN 'Wednesday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 5, 1) = 1 THEN 'Thursday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 6, 1) = 1 THEN 'Friday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 7, 1) = 1 THEN 'Saturday - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 1, 1) = 1 THEN 'Sunday - ' ELSE '' END						
							ELSE [dbo].[f_Get_MsgNamebyMsgID](50007,@Language) + ' ' +
								CASE WHEN SUBSTRING(@strTransferOption, 2, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90002,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 3, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90003,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 4, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90004,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 5, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90005,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 6, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90006,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 7, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90007,@Language) + ' - ' ELSE '' END +
								CASE WHEN SUBSTRING(@strTransferOption, 1, 1) = 1 THEN [dbo].[f_Get_MsgNamebyMsgID](90008,@Language) + ' - ' ELSE '' END
						END, @ErrCode = 201
		SELECT @ErrMsg = LEFT(@ErrMsg, LEN(@ErrMsg)-2)
	END
END
GO