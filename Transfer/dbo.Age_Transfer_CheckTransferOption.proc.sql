ALTER PROCEDURE [dbo].[Age_Transfer_CheckTransferOption]
	@CustID int, 
	@ErrMsg nvarchar(100) OUTPUT,
	@ErrCode int OUTPUT,
	@Language varchar(2) = 'E'
AS

/*
Created by: []
DB: DBTXN/CustDB
Revisions:
	- 20100413@Kiwi: Get transferoption from CustSuper/CustMaster/CustAgent
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language

----------------------------------------------------------------------
--
--Check Transfer Condition (for master and agent)
--1		2		3		4		5		6		7		8
--isSun	isMon	isTue	isWed	isThurs	isFri	isSat	isWeekly
--0		1		0		0		1		0		1		1

*/
Declare @strTransferOption varchar(8)
select @ErrCode = 0

--skip checking for direct master
if exists(select 1 from customer with (nolock) where custid = @custid and roleid = 3 and srecommend < 100)
	return

DECLARE @RoleID TINYINT
SELECT @RoleID = RoleID FROM custinfo WITH (NOLOCK) WHERE custid = @CustId

IF (@RoleID = 4)
BEGIN 
	SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
	FROM CustSuper  WITH (NOLOCK) 
	WHERE custid = @CustId
END
ELSE IF (@RoleID = 3)
BEGIN 
	SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
	FROM CustMaster  WITH (NOLOCK) 
	WHERE custid = @CustId
END
ELSE IF (@RoleID = 2)
BEGIN 
	SELECT @strTransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
	FROM CustAgent  WITH (NOLOCK) 
	WHERE custid = @CustId
END

if SUBSTRING(@strTransferOption, 8, 1) = 1 --isWeekly = 1
	AND SUBSTRING(@strTransferOption, datepart(weekday, dateadd(hh, 12, CURRENT_TIMESTAMP)), 1) = 0
BEGIN	
	Select @ErrMsg = case @Language 
						when 'E' then 'Sorry, you can only transfer on: ' +
							case when SUBSTRING(@strTransferOption, 2, 1) = 1 then 'Monday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 3, 1) = 1 then 'Tuesday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 4, 1) = 1 then 'Wednesday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 5, 1) = 1 then 'Thursday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 6, 1) = 1 then 'Friday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 7, 1) = 1 then 'Saturday - ' else '' end +
							case when SUBSTRING(@strTransferOption, 1, 1) = 1 then 'Sunday - ' else '' end						
						ELSE [dbo].[f_Get_MsgNamebyMsgID](50007,@Language) + ' ' +
							case when SUBSTRING(@strTransferOption, 2, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90002,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 3, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90003,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 4, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90004,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 5, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90005,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 6, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90006,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 7, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90007,@Language) + ' - ' else '' end +
							case when SUBSTRING(@strTransferOption, 1, 1) = 1 then [dbo].[f_Get_MsgNamebyMsgID](90008,@Language) + ' - ' else '' end
					end, @ErrCode = 201
	select @ErrMsg = left(@ErrMsg, len(@ErrMsg)-2)	
	return
END



GO
GRANT EXECUTE ON [dbo].[Age_Transfer_CheckTransferOption] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_CheckTransferOption] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Transfer_CheckTransferOption] TO [vnteam] AS [dbo]