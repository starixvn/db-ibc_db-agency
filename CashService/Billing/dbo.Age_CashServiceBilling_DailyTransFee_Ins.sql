/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE  [dbo].[Age_CashServiceBilling_DailyTransFee_Ins]
	@CustId         INT, -- Customer ID of the agent
    @ChargeDate     SMALLDATETIME, -- Date for the charge
    @IP             VARCHAR(15) = '127.0.0.1',
    @LogData        VARCHAR(MAX) = '' OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
    Created: 20250526@Bobby
    Task: Implement daily fee and free period records for agents
    DB: DBSIC-bodb02

    Revisions:
        - 20250526@Bobby: Initial [RedmineID: #227215]

    Description:
        - @CustId: Customer ID of the agent
        - @ChargeDate: Date for the charge
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @Today              SMALLDATETIME,  -- Current date without time
        @PreviousDay        SMALLDATETIME,  -- Previous day date
        @transdate          DATETIME = GETDATE(), -- Transaction date
        @winlostdate        SMALLDATETIME,
        @bettype_FEE        INT = 31005
        ;

    SELECT @winlostdate = CAST(@transdate AS DATE)
        , @Today = CAST(GETDATE() AS DATE)
        , @ErrCode = 0
        , @ErrMsg = ''
        , @ChargeDate = ISNULL(@ChargeDate, @Today) -- Default to today if not provided
        , @PreviousDay = DATEADD(DAY, -1, @ChargeDate) -- Previous day date
        , @LogData = ''
    ;

    -- Check if the agent already has a daily fee record for charge date
    IF EXISTS (
        SELECT 1
        FROM dbo.[transfer] WITH (NOLOCK)
        WHERE custid = @CustId 
            AND Winlostdate = @ChargeDate 
            AND bettype IN (@bettype_FEE) -- Daily fee types
    )
    BEGIN
        SET @ErrCode = 101;
        SET @ErrMsg = 'Daily fee record already exists for today.';
        RETURN;
    END

    -- Initialize variables
    DECLARE @amount MONEY, @chargeFEE MONEY = 0.150,
        @agentid INT, @agUser VARCHAR(50),
        @transDesc_FEE VARCHAR(1000),
        @mrecommend INT, @maUser VARCHAR(50),
        @srecommend INT, @saUser VARCHAR(50),
        @actualrate FLOAT, @currency TINYINT, @currName VARCHAR(10),
        @houseid INT, @hUser VARCHAR(30),
        @username_StarixIT VARCHAR(50), @Creator INT; 
    
    -- Get the creator's custid based on username
	SELECT @username_StarixIT = 'StarixIT',
           @hUser = 'DWLCreditCashFees',
           @agentid = @CustId
	;

    -- Get the agent's custid and other details based on CustId
    SELECT 
        @srecommend = ci.srecommend,
        @mrecommend = ci.mrecommend,
        @currency = ci.currency,
        @currName = e.currency,
        @actualrate = e.actualrate,
        @agUser = ci.username
    FROM CustDB.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
    INNER JOIN CustDB.dbo.Exchange e WITH(NOLOCK) ON ci.currency = e.exchangeId
	WHERE ci.CustId = @CustId
    AND ci.roleId  = 2 -- Ensure the customer is an agent

    IF @currency = 20 -- Ensure the currency is 20 (e.g., UUS)
    BEGIN
        SELECT @hUser = 'SUPERTEST10101097',
            @actualrate = 1.0;
    END

    -- Get the agent's custid based on username
    SELECT 
        @saUser = IIF(custid=srecommend,username,@saUser),
        @maUser = IIF(custid=mrecommend,username,@maUser)
    FROM CustDB.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
	WHERE CustId IN (@srecommend, @mrecommend)

    -- Get the creator's custid based on username
    -- House level variables for transfer records
    DECLARE
        @amountHouse        MONEY,
        @currencyHouse      TINYINT,
        @actualrateHouse    FLOAT,
        @currNameHouse      VARCHAR(10),
        @recommendHouse     INT,
        @mrecommendHouse    INT,
        @srecommendHouse    INT,
        @chargeFEE_RM       MONEY,
        @transDesc_FEE_RM   VARCHAR(1000) = ''
    ;
    SELECT 
        @creator            = IIF(ci.username = @username_StarixIT, ci.custid, @creator),
        @houseId            = IIF(ci.username = @hUser, ci.custid, @houseId),
        @currencyHouse      = IIF(ci.username = @hUser, e.exchangeId, @currencyHouse),
        @actualrateHouse    = IIF(ci.username = @hUser, e.actualrate, @actualrateHouse),
        @currNameHouse      = IIF(ci.username = @hUser, e.currency, @currNameHouse),
        @recommendHouse     = IIF(ci.username = @hUser, ci.recommend, @recommendHouse),
        @mrecommendHouse    = IIF(ci.username = @hUser, ci.mrecommend, @mrecommendHouse),
        @srecommendHouse    = IIF(ci.username = @hUser, ci.srecommend, @srecommendHouse)
    FROM CustDB.dbo.vw_CashService_Customer ci WITH(NOLOCK) 
    LEFT JOIN CustDB.dbo.Exchange e WITH(NOLOCK) ON ci.currency = e.exchangeId
	WHERE UserName IN (@username_StarixIT, @hUser)
    
    -- Check cross currency between SMA vs house level
    IF @currNameHouse <> @currName
        AND @currencyHouse <> 2 -- Ensure the house currency is 2 (e.g., RM)
    BEGIN
        SET @ErrCode = 102;
        SET @ErrMsg = 'Do not support cross currency transfer.';
        RETURN;
    END

    -- Create temp table to store transaction fee summary
    DECLARE @FeeRowCount INT;
    DECLARE @AgentTransactionFee TABLE (
        RowNum INT IDENTITY(1,1) PRIMARY KEY,
        AgentId INT,
        CompletedDate SMALLDATETIME,
        NumTrans INT,
        TransIds VARCHAR(MAX)
    );

    INSERT INTO @AgentTransactionFee(AgentId, CompletedDate, numTrans, TransIds)
    SELECT 
        ci.recommend AS AgentId
        , TRY_CAST(ct.OperatedTime AS DATE) AS CompletedDate
        , COUNT(1) AS numTrans
        , STRING_AGG(CAST(TransId AS VARCHAR(MAX)), ',') AS TransIds
    FROM dbo.[CashTransaction] ct WITH (NOLOCK)
    INNER JOIN CustDB.dbo.vw_CashService_Customer ci (NOLOCK) ON ci.custid = ct.CustId
    WHERE 
        ci.recommend = @CustId
        AND ct.OperatedTime >= @PreviousDay AND ct.OperatedTime < @ChargeDate
        AND ct.statusID = 4 -- Only consider successful transactions
        AND ct.PaymentType = 2 -- Only consider bank transactions
        AND ct.TransactionTypeID IN (1, 2, 3) -- Only consider deposits and withdrawals
        AND TRY_CAST(JSON_VALUE(ct.ExtraInfo, '$.ChargedAt') AS SMALLDATETIME) IS NULL
    GROUP BY ci.recommend
        , TRY_CAST(ct.OperatedTime AS DATE)
    HAVING COUNT(1) > 0
    ;SET @FeeRowCount = @@ROWCOUNT;
    
    -- Check if there are any transactions in @transactionFee
    IF @FeeRowCount = 0
    BEGIN
        SET @ErrCode = 103;
        SET @ErrMsg = 'There is No CASH transactions found for the agent.';
        RETURN;
    END

        
    -- Use WHILE loop to process each row in @transactionFee
    DECLARE @RowNum INT;
    DECLARE @numTrans INT = 0, @CompletedDate SMALLDATETIME, @transIds_FEE VARCHAR(MAX);

    -- Generate reference numbers for the fee and period records
    DECLARE 
          @RefNo_FEE_1      BIGINT
        , @RefNo_FEE_2      BIGINT
        , @RefNo_FEE_3      BIGINT
        , @transId_FEE_1    BIGINT = 0
        , @transId_FEE_2    BIGINT = 0
        , @transId_FEE_3    BIGINT = 0
        , @transId_FEE_4    BIGINT = 0
        , @transId_FEE_5    BIGINT = 0
        , @transId_FEE_6    BIGINT = 0  
    ;
    
    SET @RowNum = 1;
    WHILE @RowNum <= @FeeRowCount
    BEGIN
        SELECT @numTrans = 0
            , @RefNo_FEE_1 = 0, @RefNo_FEE_2 = 0, @RefNo_FEE_3 = 0
            , @transId_FEE_1 = 0, @transId_FEE_2 = 0, @transId_FEE_3 = 0
            , @transId_FEE_4 = 0, @transId_FEE_5 = 0, @transId_FEE_6 = 0
            , @amount = 0, @amountHouse = 0
            , @transDesc_FEE = '', @transDesc_FEE_RM = ''
        ;

        -- Get the current transaction type and number of transactions
        SELECT 
            @numTrans       = cf.NumTrans,
			@transIds_FEE   = cf.TransIds,
            @CompletedDate  = cf.CompletedDate
        FROM @AgentTransactionFee cf
        WHERE RowNum = @RowNum;

        -- Initialize variables for the current transaction type
        IF @bettype_FEE > 0 AND @numTrans > 0
        BEGIN
            EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_1 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_2 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_3 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_1 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_2 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_3 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_4 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_5 OUTPUT;
            EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_6 OUTPUT;
            
            -- Prepare the transaction description for fee and period records
            SELECT
                @chargeFEE_RM   =  @chargeFEE * @actualrate
                , @amount       = @numTrans * @chargeFEE
                , @amountHouse  = @amount * @actualrate
                , @transDesc_FEE = CONCAT('(Other fees charges: number of transaction ', @numTrans,' * ',@currName,' ',@chargeFEE,')')
                , @transDesc_FEE_RM = CONCAT('(Other fees charges: number of transaction ', @numTrans,' * ',@currNameHouse,' ',@chargeFEE_RM,')')
            ;

            -- You can add more logic here as needed for each transaction type
            BEGIN TRANSACTION;
            BEGIN TRY
                -- Insert the daily CASH transaction fee record for the agent
                ;WITH CTE_Transfer 
                AS (
                    
                    SELECT transId,creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                        winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                        scomm, swinlost, ip, statusID, RepUpdateTime
                    FROM (
                        VALUES 
                            ----master -> agent
                            (@transId_FEE_1, @Creator, @mrecommend, @maUser, @RefNo_FEE_1, @transdate, @bettype_FEE, 'To Customer ::: ' + @agUser + @transDesc_FEE, 
                            @amount, 0, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                            0, 0,@ip,131,SYSDATETIME()),
                            (@transId_FEE_2, @Creator, @agentid, @agUser, @RefNo_FEE_1, @transdate, @bettype_FEE, 'From Customer ::: ' + @maUser + @transDesc_FEE, 
                            0, @amount, @winlostdate, @currency, @actualrate, @currName, @agentid, @mrecommend, @srecommend, 
                            0, 0,@ip,131,SYSDATETIME()),
                            
                            ----super -> master
                            (@transId_FEE_3, @Creator, @srecommend, @saUser, @RefNo_FEE_2, @transdate, @bettype_FEE, 'To Customer ::: ' + @maUser + @transDesc_FEE, 
                            @amount, 0, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                            0, 0,@ip,131,SYSDATETIME()),
                            (@transId_FEE_4, @Creator, @mrecommend, @maUser, @RefNo_FEE_2, @transdate, @bettype_FEE, 'From Customer ::: ' + @saUser + @transDesc_FEE, 
                            0, @amount, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                            0, 0,@ip,131,SYSDATETIME()),
                            
                            ----house -> super
                            (@transId_FEE_5, @Creator, @houseid, @hUser, @RefNo_FEE_3, @transdate, @bettype_FEE, 'To Customer ::: ' + @saUser + @transDesc_FEE_RM, 
                            @amountHouse, 0, @winlostdate, @currencyHouse, @actualrateHouse, @currNameHouse, @recommendHouse, @mrecommendHouse, @srecommendHouse, 
                            0, 0,@ip,131,SYSDATETIME()),
                            (@transId_FEE_6, @Creator, @srecommend, @saUser, @RefNo_FEE_3, @transdate, @bettype_FEE, 'From Customer ::: ' + @hUser + @transDesc_FEE, 
                            0, @amount, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                            0, 0,@ip,131,SYSDATETIME())

                    ) AS T (transId,creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                        winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                        scomm, swinlost, ip, statusID, RepUpdateTime)
                    WHERE bettype IN (@bettype_FEE) -- Only insert daily fee records
                        AND RefNo > 0 -- Ensure the reference number is valid
                
                )
                --SELECT * FROM CTE_Transfer;
                INSERT INTO [Transfer]
                (transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                   winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                   scomm, swinlost,ip,statusID, RepUpdateTime)
                SELECT transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                   winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                   scomm, swinlost,ip,statusID, RepUpdateTime
                FROM CTE_Transfer
                WHERE 
                    (winlost-actual_stake) <> 0 -- Ensure the win/lost amount is non-zero

				-- UPDATE CashTransaction
				;WITH CTE_TransID AS (
					SELECT TRY_CAST([value] AS BIGINT) AS TransId
					FROM STRING_SPLIT(@transIds_FEE, ',')
				)
				UPDATE ct
				SET ct.RepUpdateTime = dbo.f_GetDateTime2()
                    , ct.ExtraInfo = JSON_MODIFY(
									JSON_MODIFY(
										JSON_MODIFY(ISNULL(ct.ExtraInfo, '{}'), '$.ChargedAt', FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss'))
										, '$.Fee', TRY_CAST(@chargeFEE AS VARCHAR(10))
									), '$.CompletedDate', FORMAT(@CompletedDate, 'yyyy-MM-dd'))
				FROM dbo.CashTransaction ct WITH(ROWLOCK, UPDLOCK)
				INNER JOIN CTE_TransID cte ON cte.TransId = ct.TransId
				;
                -- Commit the transaction if everything is successful
                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                SELECT @ErrCode = 111
                    , @ErrMsg = ERROR_MESSAGE();

                -- Rollback the transaction if any error occurs
                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;

                RETURN;
            END CATCH
        END

        SET @RowNum = @RowNum + 1;
    END

    -- Log the successful insertion
    SELECT @LogData = (
        SELECT 1 AS LogTypeId,
            @Creator AS UserID, @HouseId AS FromCustID, @AgentId AS ToCustID,
            @AgentId AS CustID, @IP AS IP,
            Doing = CONCAT('Insert Daily Cash Transaction Fee for Agent: custid=', @agentId,
                ', username=', @agUser,
                ', winlostdate=', FORMAT(@winlostdate, 'yyyy-MM-dd'),
                ', refno=', @RefNo_FEE_1)
        FOR JSON PATH
    );
END
GO