/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashWithdrawal_ManualAdd_InsTransfer
(
    @CustID INT,
    @UplineID INT,
    @Amount MONEY,
	@ExchangeRate SMALLMONEY =	1,
	@BonusID INT = NULL,
	@IP VARCHAR(50) = '',
	@RevertRefNo BIGINT = 0,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@TransferRefNo	BIGINT = NULL OUTPUT,
	@TransId_From	BIGINT = NULL OUTPUT,
	@TransId_To	BIGINT = NULL OUTPUT
)
AS
/*
	Created: 20250502@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250502@Max: Alpha - Agency Cash Service [redmine: #223896] 
		- 20250603@Max: Alpha - Agency Cash Service - Sprint 3 [redmine: #223896] 
		- 20250709@Eden: Alpha - Agency Cash Service - Sprint 6 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;
	
	DECLARE @username			VARCHAR(50),
		@currency				TINYINT,
		@currencyName			VARCHAR(5),
		@winlostdate			SMALLDATETIME,
		@beforebalance			MONEY,
		@postbalance			MONEY,
		@actualrate				FLOAT,
		@winlost				MONEY,
		@actual_stake			MONEY,
		@mrecommend				INT,
		@recommend				INT,
		@srecommend				INT,
		@roleid					TINYINT,
		@transdesc				NVARCHAR(300),
		@Count					INT,
		@transdate				DATETIME,
		@TransId				BIGINT,
		
		--Balance Account info
		@bal_mrecommend			INT,
		@bal_recommend			INT,
		@bal_srecommend			INT,
		@bal_Username			VARCHAR(50),
		@bal_currency			TINYINT,
		@bal_actualrate			FLOAT,
		@bal_currencyName		NVARCHAR(5),
		@translogCredit 		MONEY,
		@balance_bettransRNG	MONEY,
		@balance_bettransLC		MONEY,
		@balance_Transfer		MONEY,
		@bal_transid			BIGINT,

		@DWIT					SMALLINT,
		@BalanceType			TINYINT = 2,
		@IsForced				BIT = 0,
		@WalletType				TINYINT,
		@BonusWalletFlag		BIT,

		@IsDiff					SMALLINT = 1,
		@BalanceUpDate			SMALLDATETIME,
		@MoveBetsDay			SMALLDATETIME,
		@NewMoveBetsDay			SMALLDATETIME,
		@NewBalanceUpDate		SMALLDATETIME

	SELECT	@ErrCode		= 0,
			@ErrMsg			= '',
			@TransferRefNo	= ISNULL(@TransferRefNo, 0),
			@amount			= @amount,
			@DWIT			= 31002

	SELECT @username = username
		,@currency = ci.currency
		,@currencyName = e.currency
		,@actualrate = actualrate
		,@mrecommend = mrecommend
		,@recommend = recommend
		,@srecommend = srecommend
		,@roleid = roleid
		,@BonusWalletFlag = ISNULL(BonusWalletFlag,0) 
	FROM CustDB.dbo.custinfo AS ci WITH (NOLOCK)
		INNER JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON ci.currency = e.exchangeid
	WHERE custid = @custid

	--Check balance Account
	SELECT	@UplineID = custid, 
		@bal_Username = username,
		@bal_mrecommend = mrecommend, 
		@bal_recommend = recommend, 
		@bal_srecommend = srecommend,
		@bal_currency = ci.currency, 
		@bal_actualrate = actualrate, 
		@bal_currencyName = e.currency
	FROM CustDB.dbo.custinfo AS ci WITH (NOLOCK)
		INNER JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON ci.currency = e.exchangeid
	WHERE custid = @UplineID

	SELECT @winlost = 0, @actual_stake = ABS(@amount)
		,@WalletType = CASE	WHEN @BonusID > 0 THEN 2 ELSE NULL END
	
	-- PROCESS: insert transfer
	BEGIN TRY
		SELECT @Count = 0
			,@ErrMSg	= ''
			,@ErrCode	= 0;

		------------------Insert trans into DB---------------------------------------------------------------
		IF ISNULL(@RevertRefNo,0) <> 0
		BEGIN
			SET @TransferRefNo = @RevertRefNo
		END
		ELSE IF @TransferRefNo = 0
		BEGIN
			EXEC Get_Refno_Transid @RefNo = @TransferRefNo OUTPUT
		END		
		----------------------------------
		---- Checking the balance of customer before updating the amount on Credit or Debit table 

		DECLARE @Cust_Balance		MONEY,
				@Cust_Balance_ABS	MONEY,
				@stepDone			INT;
		
		SELECT	@Cust_Balance		= @winlost - @actual_stake
			, @Cust_Balance_ABS		= ABS(@Cust_Balance)		
			, @stepDone				= 0;

		--Get member balance
		EXEC dbo.Acc_CustomerSelCash_CaptureBalance @CustId = @CustId, @TotalCash = @beforebalance OUTPUT
		
		--Check enough balance for withdrawing
		IF @beforebalance - @actual_stake < 0
		BEGIN
			SELECT @ErrMsg = 'Member' + '''' + 's cash balance is insufficient.'
				, @ErrCode = 406
			RETURN
		END

		--Update BalanceDebit 
		IF @Cust_Balance < 0 
		BEGIN
			SELECT @Count = 1;
 			EXEC Dot_BalanceDebitUpd @CustID = @CustID, @balance = @Cust_balance_ABS, @type = @BalanceType, @IsForced = @IsForced, @errCode = @ErrCode OUTPUT
			IF @ErrCode <> 0
			BEGIN
				SELECT	@ErrCode = 105	
						,@ErrMsg = 'Insert transaction failed.' + ' STEP: ' + CONVERT(NVARCHAR(1), @Count) + '. ERROR_MESSAGE: Update balance debit failed'  + ' - ERROR_NUMBER: ' + CONVERT(VARCHAR(20), @ErrCode)
				
				RAISERROR(@ErrMsg, 11, 1); --- will be handled in the Begin...Catch block code
			END
			SET @stepDone += POWER(2*1, 1); --Done BalanceDebit-2^1
		END 

		SELECT @transdate = CURRENT_TIMESTAMP
			,@winlostdate = CAST(@transdate AS DATE);
		
		---get new @TransId 
		EXEC Get_Bettrans_TransID @TransID = @TransId OUTPUT
		---get new @bal_transid 
		EXEC Get_Bettrans_TransID @TransID = @bal_transid OUTPUT

		SELECT @TransId_From = @TransId, @TransId_To = @bal_transid

		BEGIN TRY
			SELECT @Count = 2
			INSERT INTO dbo.Transfer 
				(TransId, custid, username, refno, transdate, bettype, transdesc,winlost, actual_stake, winlostdate, balance,
				 creator,recommend,mrecommend,srecommend,currency,actualrate, currencyName, statusID,ip, SerialNo, RepUpdateTime)
			VALUES 
				(@TransId, @CustID, @username, @TransferRefNo, @transdate, @DWIT, 'To Customer :: ' + @bal_Username + CASE WHEN ISNULL(@RevertRefNo,0) <> 0 THEN ' (Revert)' ELSE '' END 
					,@winlost, @actual_stake, @winlostdate, ISNULL(@beforebalance, 0),
				 @CustID, @Recommend, @MRecommend, @SRecommend, @Currency,@actualrate, @currencyName, 131,@ip, NULL, SYSDATETIME()),
				 --dummy trans
				 (@bal_transid, @UplineID, @bal_Username, @TransferRefNo, @transdate, @DWIT, 'From Customer :: ' + @username + CASE WHEN ISNULL(@RevertRefNo,0) <> 0 THEN ' (Revert)' ELSE '' END
					, @actual_stake * @ExchangeRate, @winlost * @ExchangeRate, @winlostdate, NULL, 
				 @CustID, @bal_recommend, @bal_mrecommend, @bal_srecommend, @bal_currency, @bal_actualrate, @bal_currencyName, 131, @ip, '0', SYSDATETIME())
			
			SET @stepDone += POWER(2*1, 2); --Done transfer-2^2
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 108
					,@ErrMsg = 'Insert transaction failed.' + ' STEP: ' + CONVERT(NVARCHAR(1), @Count) + '. ERROR_MESSAGE: Insert transfer failed'  + ' - ERROR_NUMBER: ' + CONVERT(VARCHAR(20), @ErrCode) + '. Exception: ' + ERROR_MESSAGE();
				
			RAISERROR(@ErrMsg, 11, 1); --- will be handled in the Begin...Catch block code
		END CATCH

		---insert into new table transferinfo
		IF NOT (@WalletType IS NULL AND @BonusID IS NULL)
		BEGIN
			SELECT @Count = 4
			INSERT INTO dbo.TransferInfo(TransId, WalletType, BonusID, RepUpdateTime)
			VALUES (@TransId, @WalletType, @BonusID, SYSDATETIME())
				,(@bal_transid, @WalletType, @BonusID, SYSDATETIME());

			SET @stepDone += POWER(2*1, 4); --Done transferinfo-2^4
		END
	END TRY
	BEGIN CATCH

		WAITFOR DELAY '000:00:00.002' -- wait for in-house service

		--TODO: Unhandle exception
		SELECT @ErrCode = 110
			, @ErrMsg	= CONCAT('Insert transaction failed. Exception:' + ERROR_MESSAGE(), ', ERROR_LINE: ', ERROR_LINE(), ', ERROR_NUMBER: ', ERROR_NUMBER())
		WHERE @ErrMsg <> ERROR_MESSAGE()

		--TODO: Manually rollback transfer
		IF @stepDone & 4 = 4
		BEGIN
			UPDATE dbo.Transfer WITH(ROWLOCK)
			SET	custid = 0, 
				Recommend = 0, 
				MRecommend = 0, 
				SRecommend = 0, 
				Winlost = 0, 
				Actual_Stake = 0, 
				RepUpdateTime = SYSDATETIME()
			WHERE transid IN (@transid, @bal_transid) AND refno = @TransferRefNo
				AND @stepDone & 4 = 4
		END

		--TODO: Rollback BalanceDebit 
		IF @Cust_balance < 0 AND @stepDone & 2 = 2
		BEGIN 
 			EXEC Dot_BalanceCreditUpd @CustID = @CustID, @balance = @Cust_Balance_ABS, @type = @BalanceType
		END

		--TODO: Manually rollback transferInfo
		IF @stepDone & 16 = 16
		BEGIN
			UPDATE TransferInfo WITH(ROWLOCK)
			SET		IsDel = 1,  RepUpdateTime = SYSDATETIME()
			WHERE TransId IN (@transid, @bal_transid)
				AND @stepDone & 16 = 16
		END
	END CATCH

    SET NOCOUNT OFF;
END;