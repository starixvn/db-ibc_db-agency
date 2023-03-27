/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
CREATE OR ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_SettingDel]
	@FromCustID		INT,
	@ToCustIDs		VARCHAR(4000),
	@Creator		INT,
	@Language		VARCHAR(2)= 'E',
	@IP				VARCHAR(45)='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:
		• @FromCustID: The direct UplineID
		• @ToCustIDs: The list CustID(s) being to delete auto config

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today DATE, @tomorrow DATE, @RoleID TINYINT, @batchCount INT, @pairCount INT;

	-- Logging
	DECLARE @LogSPData	VARCHAR(8000),
		@TrackingValue2 VARCHAR(8000),
		@StartTime		DATETIME,
		@duration		INT,
		@LogActionID	INT = 95087,
		@AfftectedRows	INT;

	SELECT @today	= GETDATE()
		,@tomorrow	= DATEADD(DAY, 1, @today)
		,@StartTime = CURRENT_TIMESTAMP;

	DROP TABLE IF EXISTS #tmpClearBalanceCust;
	CREATE TABLE #tmpClearBalanceCust (FromCustID INT, ToCustID INT, CreatedDate DATETIME, EffectedDate DATE, 
		CONSTRAINT  PK_CustPair_Del PRIMARY KEY (FromCustID, ToCustID) 
	);

	SELECT @RoleID = (SELECT TOP 1 RoleID FROM CustDB.dbo.customer WITH (NOLOCK) WHERE custid = @FromCustID);

	IF @RoleID IS NULL 
	 BEGIN  
		 SELECT @ErrCode	= 102, 
				@ErrMsg		= CASE WHEN @Language = 'E' THEN 'Customer does not exist.'  
								   ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
								  END    
		RETURN  
	END  

	INSERT INTO #tmpClearBalanceCust (FromCustID, ToCustID)
	SELECT DISTINCT @FromCustID AS FromCustID, t.value
	FROM STRING_SPLIT(@ToCustIDs, ',') AS t;

	SET @batchCount = @@ROWCOUNT;

	SELECT @pairCount = (
		SELECT COUNT(1) AS PairCount
			FROM CustDB.dbo.customer c WITH (NOLOCK) 
			INNER JOIN #tmpClearBalanceCust cbs ON cbs.ToCustID = c.custid
		WHERE 1 = CASE 
				WHEN @RoleID = 2 AND c.recommend = @FromCustID THEN 1
				WHEN @RoleID = 3 AND c.mrecommend = @FromCustID THEN 1
				WHEN @RoleID = 4 AND c.srecommend = @FromCustID THEN 1
				ELSE 0
			END
	);

	IF @batchCount <> @pairCount
	BEGIN  
		SELECT @ErrCode	= 103, 
				@ErrMsg	= CASE WHEN @Language = 'E' THEN 'Downline does not match.'  
								ELSE [dbo].[f_Get_MsgNamebyMsgID](40014,@Language)
							END    
		RETURN
	END  

	 IF EXISTS (
		SELECT TOP 1 1 AS HasRunning
		FROM dbo.Age_ClearBalanceCust_Process WITH(NOLOCK)
		WHERE SessionDate = @today
			AND [Status] IN ('New', 'Waiting', 'Running')
			OR ([Status] = 'Failed' AND TryCount BETWEEN 1 AND 4)
	 )
	 BEGIN
		SELECT @ErrCode	= 104, 
				@ErrMsg	= CASE WHEN @Language = 'E' THEN 'The Auto Transfer is in progress. Please turn off the auto transfer after the process is done.'  
								ELSE [dbo].[f_Get_MsgNamebyMsgID](500019,@Language)
							END    
		RETURN
	END

	--TODO: Remove auto transfer setting
	DECLARE @tmpResult TABLE (CustId INT);
	BEGIN TRY
		WITH CTE_Remove AS (
			SELECT del.FromCustID, del.ToCustID 
			FROM #tmpClearBalanceCust del
			INNER JOIN [dbo].[Age_ClearBalanceCust_Setting] s (NOLOCK) 
				ON s.FromCustID = del.FromCustID 
				AND s.ToCustID = del.ToCustID
		)
		DELETE d WITH(ROWLOCK)
		OUTPUT DELETED.ToCustId
		INTO @tmpResult(CustId)
		FROM [dbo].[Age_ClearBalanceCust_Setting] d
		INNER JOIN CTE_Remove cte ON cte.FromCustID = d.FromCustID AND cte.ToCustID = d.ToCustID;
		
		SET @AfftectedRows = @@ROWCOUNT;
		IF @AfftectedRows = 0
			RETURN

		DECLARE @LogToCustIds VARCHAR(8000);
		SET @duration  = DATEDIFF(MILLISECOND, @StartTime, CURRENT_TIMESTAMP);
		SELECT @LogToCustIds = (SELECT CONCAT(CustId,',') AS 'text()'
						FROM @tmpResult
						FOR XML PATH(''), TYPE).value('text()[1]','VARCHAR(8000)')

		-- TODO: Write log runSP
		BEGIN TRY
			SELECT @TrackingValue2 = CAST(
				(SELECT @FromCustID AS '@FromCustId', @LogToCustIds AS '@ToCustIds', 
					ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @Creator AS '@Creator'
				FOR XML PATH('Age_ClearBalanceCust_SettingDel')) AS VARCHAR(8000)
			);

			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				@UserID = @Creator,
				@CustID = @FromCustID,
				@ActionID = @LogActionID,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @TrackingValue2,
				@duration = @duration
		END TRY
		BEGIN CATCH
			SELECT @TrackingValue2 = CAST(
				(SELECT @FromCustId AS '@FromCustId', @LogToCustIds AS '@ToCustIds', 
					ISNULL(@IP, SPACE(1)) AS '@IP', @Language AS '@Language', @Creator AS '@Creator',
					ERROR_NUMBER() AS '@ErrCode', ERROR_MESSAGE() AS '@ErrMsg'
				FOR XML PATH('Age_ClearBalanceCust_SettingDel')) AS VARCHAR(8000)
			);

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
				@UserID = @Creator,
				@CustID = @FromCustID,
				@ActionID = @LogActionID,
				@TrackingValue = @LogSPData,
				@TrackingValue2 = @TrackingValue2,
				@duration = @duration

		END CATCH

	END TRY
	BEGIN CATCH
		SELECT @ErrCode	= 105, 
				@ErrMsg	= ERROR_MESSAGE() 
	END CATCH
END
GO