/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashTransaction_Upd
(
	@TransId BIGINT,
	@AdjustCreditAmt MONEY = NULL,
	@StatusId	TINYINT = NULL,
	@Amount MONEY = NULL,
	@Remark	nvarchar(1000) = NULL,
	@TransferRefNo	BIGINT = NULL,
	@OperatedBy INT = NULL,
	@SubAccID	int = NULL, 
	@PaymentType	TINYINT = NULL,
	@PaymentMethod	TINYINT = NULL,
	@PaymentFrom varchar(100) = NULL,
	@PaymentTo varchar(100) = NULL,
	@PaySlip VARBINARY(MAX) = NULL,
	@ExtraInfo nvarchar(1000) = NULL,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:
*/ 
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY
		UPDATE c WITH (ROWLOCK, UPDLOCK)
		SET c.StatusId = ISNULL(@StatusId,c.StatusId),
			c.Amount = ISNULL(@Amount,c.Amount),
			c.Remark = ISNULL(@Remark,c.Remark),
			c.TransferRefNo = ISNULL(@TransferRefNo,c.TransferRefNo),
			c.OperatedBy = ISNULL(@OperatedBy,c.OperatedBy),
			c.OperatedTime = GETDATE(),
			c.SubAccID = ISNULL(@SubAccID,c.SubAccID),
			c.PaymentType = ISNULL(@PaymentType,c.PaymentType),
			c.PaymentMethod = ISNULL(@PaymentMethod,c.PaymentMethod),
			c.PaymentFrom = ISNULL(@PaymentFrom,c.PaymentFrom),
			c.PaymentTo = ISNULL(@PaymentTo,c.PaymentTo),
			c.PaySlip = ISNULL(@PaySlip,c.PaySlip),
			c.ExtraInfo = ISNULL(@ExtraInfo,c.ExtraInfo),
			c.AdjustCreditAmt = ISNULL(@AdjustCreditAmt,c.AdjustCreditAmt),
			c.RepUpdateTime = dbo.f_GetDateTime2()
		FROM dbo.CashTransaction c
		WHERE c.TransId = @TransId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH
END;