/*<info serverAlias="DBSIC-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE Age_CashAccumulatedCredit_Adjust
	@CustID		INT = NULL,
	@ActionType	TINYINT = NULL ,
	@Amount		MONEY = 0,
	@AdjustCreditAmt MONEY = 0 OUTPUT,
	@CashAccumCreditTbl VARCHAR(MAX) = '' OUTPUT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) OUTPUT
AS 
/*
	Created: 20250423@Eden		
	Task: Insert, Update Cash Member Accumulated Credit
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250709@Eden: Alpha - Agency Cash Service - Sprint 6 [redmine: #223896] 

	Parameter's Explanation:			
		@ActionType: 
				1 - Deposit
				2 - Withdrawal
				3 - AdjustLoss (Schedule Job)
				4 - Revert Deposit
				5 - Revert Withdrawal
				6 - Bonus
		@Amount : Action amount ( ex: Deposit 100, Withdrawal 100...)
		@AdjustCreditAmt: Real adjusted amount on AccumCreditReturn column
	*/ 
BEGIN
	SET NOCOUNT ON

	SELECT @AdjustCreditAmt = 0, @ErrCode = 0

	IF ISNULL(@Amount,0) = 0
	BEGIN
		SELECT @ErrCode = 1 --'Amount = 0'
			  ,@ErrMsg = 'Amount = 0'
		RETURN
	END

	IF @ActionType IN (1,5,6) --Increase AccumCreditReturn --> Positive Value
		SELECT @Amount = ABS(@Amount)
	ELSE IF @ActionType IN (2,3,4) --Decrease AccumCreditReturn --> negavtive Value
		SELECT @Amount = - ABS(@Amount)
	ELSE 
	BEGIN
		SELECT @ErrCode = 2 --'Invalid ActionType'
			  ,@ErrMsg = 'Invalid ActionType'
		RETURN
	END
	
	IF @Amount < 0 
		AND (SELECT AccumCreditReturn FROM dbo.f_Age_CashAccumCredit_MemberSel(@CustID)) = 0 
	BEGIN
		RETURN
	END

	DECLARE @CashAccumCredit TABLE (
		CustID INT NOT NULL,
		recommend INT NOT NULL,
		mrecommend INT NOT NULL,
		srecommend INT NOT NULL,
		AccumCreditReturn MONEY NOT NULL,
		ModifiedDate DATETIME NOT NULL,
		RepUpdateTime DATETIME2 NULL
	)
	
	INSERT INTO CashAccumCredit(CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime)
	OUTPUT inserted.CustID, inserted.recommend,inserted.mrecommend,inserted.srecommend,inserted.AccumCreditReturn,inserted.ModifiedDate,inserted.RepUpdateTime
	INTO @CashAccumCredit(CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime)
	SELECT ci.CustID,ci.recommend,ci.mrecommend,ci.srecommend,@Amount,GETDATE(),dbo.f_GetDateTime2()
	FROM custdb.dbo.custInfo ci WITH(NOLOCK)
	WHERE ci.CustID = @CustID
		AND NOT EXISTS(	SELECT 1 
				FROM CashAccumCredit c WITH (HOLDLOCK,UPDLOCK) 
				WHERE c.CustID = @CustID
				)
	
	IF NOT EXISTS( SELECT 1 FROM @CashAccumCredit)
	BEGIN
		UPDATE c
		SET @AdjustCreditAmt = CASE  WHEN c.AccumCreditReturn + @Amount >= 0 THEN @Amount 
									 ELSE - c.AccumCreditReturn 
								END,
			c.AccumCreditReturn = c.AccumCreditReturn + @AdjustCreditAmt,
			c.ModifiedDate = GETDATE(),
			c.RepUpdateTime = dbo.f_GetDateTime2()
		OUTPUT inserted.CustID, inserted.recommend,inserted.mrecommend,inserted.srecommend,inserted.AccumCreditReturn,inserted.ModifiedDate,inserted.RepUpdateTime
		INTO @CashAccumCredit(CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime)
		FROM CashAccumCredit c WITH (ROWLOCK,UPDLOCK) 
		WHERE c.CustID = @CustID
	END
	ELSE
	BEGIN
		SET @AdjustCreditAmt = @Amount
	END

	SELECT @CashAccumCreditTbl = (
		SELECT CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime
		FROM @CashAccumCredit
		FOR JSON PATH
	)
END
GO
/*
Examples:
	DECLARE @AdjustCreditAmt MONEY,
			@ErrCode INT,
			@ErrMsg VARCHAR(2000),
			@CashAccumCreditTbl VARCHAR(MAX),
			@CustID INT = 1176092
	EXEC Age_CashAccumulatedCredit_Adjust 
			@CustID = @CustID
		,@ActionType = 1
		,@Amount = 8
		,@AdjustCreditAmt = @AdjustCreditAmt OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		,@CashAccumCreditTbl = @CashAccumCreditTbl OUTPUT

	SELECT @AdjustCreditAmt AS AdjustCreditAmt 
		,@ErrCode AS ErrCode 
		,@ErrMsg AS ErrMsg
		,@CashAccumCreditTbl AS CashAccumCreditTbl

	SELECT * FROM CashAccumCredit WITH(NOLOCK) WHERE custid =  @CustID
	
	GO
	DECLARE @AdjustCreditAmt MONEY,
			@ErrCode INT,
			@ErrMsg VARCHAR(2000),
			@CashAccumCreditTbl VARCHAR(MAX),
			@CustID INT = 1176092
	EXEC Age_CashAccumulatedCredit_Adjust 
			@CustID = @CustID
		,@ActionType = 2
		,@Amount = 15
		,@AdjustCreditAmt = @AdjustCreditAmt OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		,@CashAccumCreditTbl = @CashAccumCreditTbl OUTPUT

	SELECT @AdjustCreditAmt AS AdjustCreditAmt 
		,@ErrCode AS ErrCode 
		,@ErrMsg AS ErrMsg
		,@CashAccumCreditTbl AS CashAccumCreditTbl

	SELECT * FROM CashAccumCredit WITH(NOLOCK) WHERE custid =  @CustID
*/