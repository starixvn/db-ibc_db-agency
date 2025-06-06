/*<info serverAlias="DBSIC-bodb02" executers="wsv_CashService" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE  [dbo].[Age_CashServiceBilling_DailyFee_Ins]
	@CustId         INT, -- Customer ID of the agent
    @TrialEndTime   SMALLDATETIME, -- Trial end time for the agent 
    @IP             VARCHAR(15) = '127.0.0.1',
    @LogData        NVARCHAR(MAX) = '' OUTPUT, -- Log data for the operation
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
  Created: 20250526@Bobby
  Task: Implement daily fee and free period records for agents
  DB: DBSIC-bodb02
  
  Revisions:
    - 20250526@Bobby: Initial [RedmineID: #227215]
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @Today              SMALLDATETIME,  -- Current date without time
        @transdate          DATETIME = GETDATE(), -- Transaction date
        @winlostdate        SMALLDATETIME,
        @bettype_FEE        INT,
        @bettype_PERIOD     INT
    ;

    SELECT @winlostdate = CAST(@transdate AS DATE)
        , @Today = CAST(GETDATE() AS DATE)
        , @ErrCode = 0
        , @ErrMsg = ''
        , @bettype_FEE      = 31003
        , @bettype_PERIOD   = 31004
        , @LogData = ''
    ;

    -- Check if the agent already has a daily fee record for today
    IF EXISTS (
        SELECT TOP 1 1
        FROM dbo.[transfer] WITH (NOLOCK)
        WHERE custid = @CustId 
            AND Winlostdate = @Today 
            AND bettype IN (@bettype_FEE, @bettype_PERIOD) -- Daily fee types
    )
    BEGIN
        SET @ErrCode = 101;
        SET @ErrMsg = CONCAT('Daily fee record already exists for today. CustId = ', @CustId, ', Today = ', FORMAT(@Today, 'yyyy-MM-dd'));
        RETURN;
    END

    DECLARE @amount MONEY;
    DECLARE @agentid INT, @agUser VARCHAR(50);
    DECLARE @transDesc_FEE VARCHAR(1000), @transDesc_PERIOD VARCHAR(1000);

    DECLARE @mrecommend INT, @maUser VARCHAR(50);
    DECLARE @srecommend INT, @saUser VARCHAR(50);
    DECLARE @actualrate FLOAT, @currency TINYINT = 20, @currName VARCHAR(10);
    DECLARE @houseid INT, @hUser VARCHAR(30);
    DECLARE @username_StarixIT VARCHAR(50), @Creator INT; 
    -- Get the creator's custid based on username
	SELECT @username_StarixIT = 'StarixIT',
           @hUser = 'DWLCreditCashFees',
           @AgentId = @CustId
	;

    -- Get the agent's custid and other details based on CustId
    SELECT 
        @srecommend = ci.srecommend,
        @mrecommend = ci.mrecommend,
        @currency = ci.currency,
        @currName = e.currency,
        @actualrate = e.actualrate,
        @agUser = ci.username
    FROM CustDB.dbo.custInfo ci WITH(NOLOCK) 
    INNER JOIN CustDB.dbo.Exchange e WITH(NOLOCK) ON ci.currency = e.exchangeId
	WHERE ci.CustId = @CustId
        AND ci.roleId  = 2 -- Ensure the customer is an agent

    -- Get the agent's custid based on username
    SELECT 
        @saUser = IIF(custid=srecommend,username,@saUser),
        @maUser = IIF(custid=mrecommend,username,@maUser)
    FROM CustDB.dbo.custInfo ci WITH(NOLOCK) 
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
        @srecommendHouse    INT
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

    -- Generate reference numbers for the fee and period records
    DECLARE @RefNo_FEE_1    BIGINT
        , @RefNo_FEE_2      BIGINT
        , @RefNo_FEE_3      BIGINT
        , @transId_FEE_1    BIGINT = 0
        , @transId_FEE_2    BIGINT = 0
        , @transId_FEE_3    BIGINT = 0
        , @transId_FEE_4    BIGINT = 0
        , @transId_FEE_5    BIGINT = 0
        , @transId_FEE_6    BIGINT = 0
        
    ;
    DECLARE @RefNo_PERIOD_1 BIGINT = 0
        , @RefNo_PERIOD_2   BIGINT = 0
        , @RefNo_PERIOD_3   BIGINT = 0
        , @transId_PERIOD_1 BIGINT = 0
        , @transId_PERIOD_2 BIGINT = 0
        , @transId_PERIOD_3 BIGINT = 0
        , @transId_PERIOD_4 BIGINT = 0
        , @transId_PERIOD_5 BIGINT = 0
        , @transId_PERIOD_6 BIGINT = 0
    ;

    EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_1 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_2 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_FEE_3 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_1 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_2 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_3 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_4 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_5 OUTPUT;
    EXEC dbo.Get_Refno_Transid @RefNo = @transId_FEE_6 OUTPUT;

    IF @TrialEndTime >= @Today
    BEGIN
        EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_PERIOD_1 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_PERIOD_2 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @RefNo_PERIOD_3 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_1 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_2 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_3 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_4 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_5 OUTPUT;
        EXEC dbo.Get_Refno_Transid @RefNo = @transId_PERIOD_6 OUTPUT;
    END

    -- Prepare the transaction description for fee and period records
    SELECT @transDesc_FEE = '(Cash services fees charged to '+@agUser+')',
        @transDesc_PERIOD = '(Free period to '+@agUser+')',
        @amount = 200,
        @amountHouse = @amount * @actualrate
    ;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insert the daily fee record for the agent
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
                    (@transId_FEE_5, @Creator, @houseid, @hUser, @RefNo_FEE_3, @transdate, @bettype_FEE, 'To Customer ::: ' + @saUser + @transDesc_FEE, 
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

            UNION ALL
            -- Insert daily free period records for the agent
            SELECT transId, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                scomm, swinlost, ip, statusID, RepUpdateTime
            FROM (
                VALUES 
                    ----master -> agent
                    (@transId_PERIOD_1, @Creator, @mrecommend, @maUser, @RefNo_PERIOD_1, @transdate, @bettype_PERIOD, 'To Customer ::: ' + @agUser + @transDesc_PERIOD, 
                    0, @amount, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                    0, 0,@ip,131,SYSDATETIME()),
                    (@transId_PERIOD_2, @Creator, @agentid, @agUser, @RefNo_PERIOD_1, @transdate, @bettype_PERIOD, 'From Customer ::: ' + @maUser + @transDesc_PERIOD, 
                    @amount, 0, @winlostdate, @currency, @actualrate, @currName, @agentid, @mrecommend, @srecommend, 
                    0, 0,@ip,131,SYSDATETIME()),
                    
                    ----super -> master
                    (@transId_PERIOD_3, @Creator, @srecommend, @saUser, @RefNo_PERIOD_2, @transdate, @bettype_PERIOD, 'To Customer ::: ' + @maUser + @transDesc_PERIOD, 
                    0, @amount, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                    0, 0,@ip,131,SYSDATETIME()),
                    (@transId_PERIOD_4, @Creator, @mrecommend, @maUser, @RefNo_PERIOD_2, @transdate, @bettype_PERIOD, 'From Customer ::: ' + @saUser + @transDesc_PERIOD, 
                    @amount, 0, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                    0, 0,@ip,131,SYSDATETIME()),
                    
                    ----house -> super
                    (@transId_PERIOD_5, @Creator, @houseid, @hUser, @RefNo_PERIOD_3, @transdate, @bettype_PERIOD, 'To Customer ::: ' + @saUser + @transDesc_PERIOD, 
                    0, @amountHouse, @winlostdate, @currencyHouse, @actualrateHouse, @currNameHouse, @recommendHouse, @mrecommendHouse, @srecommendHouse, 
                    0, 0,@ip,131,SYSDATETIME()),
                    (@transId_PERIOD_6, @Creator, @srecommend, @saUser, @RefNo_PERIOD_3, @transdate, @bettype_PERIOD, 'From Customer ::: ' + @hUser + @transDesc_PERIOD, 
                    @amount, 0, @winlostdate, @currency, @actualrate, @currName, 0, @mrecommend, @srecommend, 
                    0, 0,@ip,131,SYSDATETIME())

            ) AS T (transId, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
                winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
                scomm, swinlost, ip, statusID, RepUpdateTime)
            WHERE bettype IN (@bettype_PERIOD) -- Only insert daily period records
                AND @Today <= @TrialEndTime -- Ensure the record is within the trial period
                AND RefNo > 0 -- Ensure the reference number is valid
        
        )
        -- SELECT * FROM CTE_Transfer
        INSERT INTO [Transfer]
        (transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
            winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
            scomm, swinlost,ip,statusID, RepUpdateTime)
        SELECT transid, creator, custid, username, refno, transdate, bettype, transdesc, winlost, actual_stake, 
            winlostdate, currency, actualrate, currencyName, recommend, mrecommend, srecommend, 
            scomm, swinlost,ip,statusID, RepUpdateTime
        FROM CTE_Transfer

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

    -- Log the successful insertion
    SELECT @LogData = (
        SELECT 1 AS LogTypeId,
            @Creator AS UserID, @HouseId AS FromCustID, @AgentId AS ToCustID,
            @AgentId AS CustID, @IP AS IP,
            Doing = CONCAT('Insert Daily Fee and Period Records for Agent: custid=', @custid,
                ', username=', @agUser,
                ', winlostdate: ' + FORMAT(@winlostdate, 'yyyy-MM-dd'),
                ', Trial End Time: ' + FORMAT(@TrialEndTime, 'yyyy-MM-dd'),
                ', refno=', @RefNo_FEE_1)
        FOR JSON PATH
    );
END
GO