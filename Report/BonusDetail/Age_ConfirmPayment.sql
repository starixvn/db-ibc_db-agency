/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_ConfirmPayment]
	@UserId INT
	,@SubAccId INT
	,@CustId	INT
	,@TransId BIGINT
	,@PaymentDate DATETIME
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT	

AS

/*
Created: 
Task : Set up Bonus feature for IBCIndo
DB: DBTXN/bodb02

Revisions:
	- 20200104@Malcolm: Set up Bonus feature for IBCIndo [RedmineID: #147430]

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @LogSPData VARCHAR(MAX)

	UPDATE b WITH(ROWLOCK)
		SET b.PaymentDate = @PaymentDate
	FROM dbo.BonusTrans b
	WHERE b.TransId = @TransId AND b.StatusId = 0

	IF @@ROWCOUNT = 0
	BEGIN
		 SELECT @ErrCode = 101, @ErrMsg = 'The selected Bonus is not Pending anymore, you cannot confirm its payment.'
	END

	SELECT @EndRun = GETDATE(), @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

	EXEC  DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP
				 @UserID = @UserID, 
				 @CustId = @CustId,
				 @ActionID = 95038,
			     @TrackingValue = @LogSPData,
				 @duration = @duration

	SET NOCOUNT OFF;
END

GO