/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashTransaction_Ins 
(
	@CustID INT,
	@TransactionTypeID TINYINT,
	@StatusId TINYINT = NULL,
	@Amount MONEY,
	@Creator INT,
	@Remark NVARCHAR(1000) = NULL,
	@SiteDBGroupID SMALLINT,
	@TransferRefNo BIGINT = NULL,
	@OperatedBy INT = NULL,
	@OperatedTime DATETIME = NULL,
	@SubAccID INT = 0,
	@PaymentType TINYINT = NULL,
	@PaymentMethod TINYINT = NULL,
	@PaymentFrom VARCHAR(100) = NULL,
    @PaymentTo VARCHAR(100) = NULL,
    @PaySlip VARBINARY(MAX) = NULL,
    @ExtraInfo	NVARCHAR(1000) = NULL,
	@AdjustCreditAmt MONEY = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransId	BIGINT = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 

	Parameter's Explanation:
		@TransactionTypeID:  
			1  : Manual Deposit
			2  : Auto Deposit
			3  : Manual Withdrawal
			4  : Auto Withdrawal
			10 : System Adjust
*/ 
BEGIN
    SET NOCOUNT ON;

	IF @SiteDBGroupID <> dbo.f_Get_SiteDBGroupID() OR @SiteDBGroupID IS NULL
	BEGIN
		SELECT @ErrCode = 101
			,@ErrMsg = 'Wrong SiteDB'

		RETURN
	END

	BEGIN TRY
		INSERT INTO dbo.CashTransaction (
			 CustId
			,TransactionTypeID
			,StatusId
			,Amount
			,CreatedTime
			,Creator
			,Remark
			,RepUpdateTime
			,SiteDBGroupID
			,TransferRefNo
			,OperatedBy
			,OperatedTime
			,SubAccID
			,PaymentType
			,PaymentMethod
			,PaymentFrom
			,PaymentTo
			,PaySlip
			,ExtraInfo
			,AdjustCreditAmt
		)
		SELECT @CustID, @TransactionTypeID, @StatusId, @Amount, GETDATE(), @Creator, @Remark, SYSDATETIME(), @SiteDBGroupID, @TransferRefNo
			,@OperatedBy, @OperatedTime, @SubAccID, @PaymentType, @PaymentMethod, @PaymentFrom, @PaymentTo, @PaySlip, @ExtraInfo, @AdjustCreditAmt

		SET @TransId = SCOPE_IDENTITY()
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH

    SET NOCOUNT OFF;
END;