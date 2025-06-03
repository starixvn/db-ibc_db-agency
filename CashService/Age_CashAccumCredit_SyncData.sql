/*<info serverAlias="DBCUST-CustDB" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE Age_CashAccumCredit_SyncData
	@CashAccumCreditTbl VARCHAR(MAX) = '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) OUTPUT
AS 
/*
	Created: 20250423@Eden		
	Task: Sync data CashAccumCredit
	DB:  DBCUST-CustDB
		
	Revisions:
		- 20250423@Eden: Alpha - Agency Cash Service [redmine: #223896] 

	Parameter's Explanation:	
	Sample:
		DECLARE @ErrCode INT,
				@ErrMsg VARCHAR(2000),
				@CashAccumCreditTbl VARCHAR(MAX) =  '[
					{"CustID":1176092,"recommend":1176086,"mrecommend":1176083,"srecommend":1176070,"AccumCreditReturn":150.0000,"ModifiedDate":"2025-05-04T03:15:40.200","RepUpdateTime":"2025-05-05T03:17:39.2050251"}
					,{"CustID":1584729,"recommend":1176086,"mrecommend":1176083,"srecommend":1176070,"AccumCreditReturn":151.0000,"ModifiedDate":"2025-05-04T03:15:40.200","RepUpdateTime":"2025-05-05T03:17:39.2050251"}
					,{"CustID":1584727,"recommend":1176086,"mrecommend":1176083,"srecommend":1176070,"AccumCreditReturn":152.0000,"ModifiedDate":"2025-05-04T03:15:40.200","RepUpdateTime":"2025-05-05T03:17:39.2050251"}
				]'
		EXEC Age_CashAccumCredit_SyncData 
			 @ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@CashAccumCreditTbl = @CashAccumCreditTbl 

		SELECT @ErrCode AS ErrCode 
			,@ErrMsg AS ErrMsg

		SELECT * FROM CashAccumCredit WITH(NOLOCK) WHERE custid = 1176092
	*/ 
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchNum INT = 1000

	DECLARE @CashAccumCredit TABLE (
		CustID INT NOT NULL,
		recommend INT NOT NULL,
		mrecommend INT NOT NULL,
		srecommend INT NOT NULL,
		AccumCreditReturn MONEY NOT NULL,
		ModifiedDate DATETIME NOT NULL,
		RepUpdateTime DATETIME2 NULL
	)

	DECLARE @CashAccumCredit_Batch TABLE (
		CustID INT NOT NULL,
		recommend INT NOT NULL,
		mrecommend INT NOT NULL,
		srecommend INT NOT NULL,
		AccumCreditReturn MONEY NOT NULL,
		ModifiedDate DATETIME NOT NULL,
		RepUpdateTime DATETIME2 NULL
	)

	BEGIN TRY
		INSERT INTO @CashAccumCredit (CustID, recommend, mrecommend, srecommend, AccumCreditReturn, ModifiedDate, RepUpdateTime)
		SELECT custid,
			recommend,
			mrecommend,
			srecommend,
			AccumCreditReturn,
			ModifiedDate,
			RepUpdateTime
		FROM OPENJSON(@CashAccumCreditTbl) WITH (
			custid INT '$.CustID',
			recommend INT '$.recommend',
			mrecommend INT '$.mrecommend',
			srecommend INT '$.srecommend',
			AccumCreditReturn MONEY '$.AccumCreditReturn',
			ModifiedDate DATETIME '$.ModifiedDate',
			RepUpdateTime DATETIME2 '$.RepUpdateTime'
		);

		WHILE 1 = 1
		BEGIN
			DELETE FROM @CashAccumCredit_Batch

			DELETE TOP(@BatchNum) t 
			OUTPUT deleted.CustID, deleted.recommend,deleted.mrecommend,deleted.srecommend,deleted.AccumCreditReturn,deleted.ModifiedDate,deleted.RepUpdateTime
			INTO @CashAccumCredit_Batch(CustID,recommend,mrecommend,srecommend,AccumCreditReturn,ModifiedDate,RepUpdateTime)
			FROM @CashAccumCredit t

			IF @@ROWCOUNT = 0
				RETURN

			UPDATE t
			SET	t.recommend = s.recommend,
				t.mrecommend = s.mrecommend,
				t.srecommend = s.srecommend,
				t.AccumCreditReturn = s.AccumCreditReturn,
				t.ModifiedDate = s.ModifiedDate,
				t.RepUpdateTime = s.RepUpdateTime
			FROM [dbo].CashAccumCredit [t] WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @CashAccumCredit_Batch [s]
				ON [t].CustID = [s].CustID
			WHERE s.RepUpdateTime > ISNULL(t.RepUpdateTime, '')

			INSERT INTO [dbo].CashAccumCredit (
					[CustID],
					[recommend],
					[mrecommend],
					[srecommend],
					[AccumCreditReturn],
					[ModifiedDate],
					[RepUpdateTime])
			SELECT
					s.CustID,
					s.recommend,
					s.mrecommend,
					s.srecommend,
					s.AccumCreditReturn,
					s.ModifiedDate,
					s.RepUpdateTime
			FROM  @CashAccumCredit_Batch [s]
			WHERE NOT EXISTS(	SELECT 1 
								FROM [dbo].CashAccumCredit [t] WITH(UPDLOCK,HOLDLOCK)
								WHERE [t].CustID = [s].CustID
							)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			 , @ErrMsg = ERROR_MESSAGE ()

		RETURN
	END CATCH
END
GO
