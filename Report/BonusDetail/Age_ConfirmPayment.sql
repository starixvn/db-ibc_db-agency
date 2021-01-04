/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ConfirmPayment]
	@UserId			INT
	,@SubAccId		INT = NULL
	,@CustId		INT
	,@TransId		BIGINT
	,@PaymentDate	DATETIME
	,@LoginIP 		NVARCHAR(20) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = '' OUTPUT	

AS

/*
Created: 
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20210104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @LogSPData VARCHAR(MAX), @SubAccountName VARCHAR(50) = ''

	BEGIN TRY
		UPDATE b WITH(ROWLOCK)
		SET b.PaymentDate = @PaymentDate, b.StatusId = 2
		FROM dbo.BonusTrans b
		WHERE b.TransId = @TransId AND b.StatusId = 0

		IF @@ROWCOUNT = 0
		BEGIN
			 SELECT @ErrCode = 101, @ErrMsg = 'The selected Bonus is not Pending anymore, you cannot confirm its payment.'
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	IF @SubAccId IS NOT NULL
	BEGIN
		SELECT @SubAccountName = dbo.f_GetSubUsername(@SubAccId)
	END

	SELECT @LogSPData = '<Age_ConfirmPayment SubAccountName="'+ @SubAccountName +'" RefNo="'+CONVERT(VARCHAR(30), @TransId)+'" PaymentDate="'+ CONVERT(VARCHAR(50), @PaymentDate, 101)+'" IP="'+@LoginIP+'"/>'

	EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 95039,
			     @TrackingValue = @LogSPData,
				 @duration = @duration

	SET NOCOUNT OFF;
END

GO