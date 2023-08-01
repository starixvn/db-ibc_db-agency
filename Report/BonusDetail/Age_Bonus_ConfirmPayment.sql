/*<info serverAlias="DBCTG-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Bonus_ConfirmPayment]
	@UserId			INT
	,@SubAccId		INT = NULL
	,@CustId		INT
	,@TransId		BIGINT
	,@PaymentDate	DATETIME
	,@LoginIP 		NVARCHAR(20) = ''
	,@Language		NVARCHAR(5)='E' 
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = '' OUTPUT	

AS

/*
Created: 20210104@Malcolm
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]
	- 20230627@Danny: Change Meta data  [Redmine: #189515]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @LogSPData VARCHAR(MAX), @SubAccountName VARCHAR(50) = '',@CreatedDate DATE = NULL

	SELECT @CreatedDate = CONVERT(DATE, CreatedDate) FROM dbo.BonusTrans WITH(NOLOCK) WHERE BonusTransId = @TransId

	IF @CreatedDate > @PaymentDate
	BEGIN
		SELECT @ErrMsg = dbo.f_Get_MsgNamebyMsgID(50016, @Language), @ErrCode = 100
		RETURN
	END

	BEGIN TRY
		UPDATE b WITH(ROWLOCK)
		SET b.PaymentDate = @PaymentDate, b.StatusId = 2
		FROM dbo.BonusTrans b
		WHERE b.BonusTransId = @TransId AND b.StatusId = 0

		IF @@ROWCOUNT = 0
		BEGIN
			 SELECT @ErrCode = 101, @ErrMsg = dbo.f_Get_MsgNamebyMsgID(50017, @Language)
			 RETURN
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	IF @SubAccId IS NOT NULL
	BEGIN
		SELECT @SubAccountName = username From DBCust.CustDB.dbo.custSub WITH(NOLOCK) WHERE SubAccID = @SubAccId
	END

	SELECT @LogSPData = '<Age_Bonus_ConfirmPayment SubAcc="'+ @SubAccountName +'" RefNo="'+CONVERT(VARCHAR(30), @TransId)+'" PaymentDate="'+ CONVERT(VARCHAR(50), @PaymentDate, 101)+'" IP="'+@LoginIP+'"/>'

	EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 708,
			     @TrackingValue = @LogSPData,
				 @duration = @duration

	SET NOCOUNT OFF;
END

GO