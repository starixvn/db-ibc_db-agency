/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ToastMessage_SetRead]
	@TargetId			INT,
	@ToastId			INT,
	@IsRead				BIT,
	@SubAccId			INT = NULL,
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20230831@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBMSG-bodb_Message

	Revisions:
		- 20230831@Bobby: AutoJob clear balance downlines - Notice message [RedmineID: #182071]

	Param's Explanation:
		• @PairOfBatch: The number pairs of batch

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SiteFunctionName	VARCHAR(100);

	SELECT 	@ErrCode		= 0,
			@ErrMsg			= '',
			@SubAccId		= ISNULL(@SubAccId, 0)
	;

	SELECT TOP 1 @SiteFunctionName = SiteFunctionName 
    FROM dbo.ToastSiteFunction ts WITH(NOLOCK) 
		INNER JOIN dbo.ToastMessage tm WITH(NOLOCK) ON tm.SiteFunctionId = ts.SiteFunctionId
    WHERE tm.ToastId = @ToastId;

	--TODO: Update owner toast message
	DECLARE @newRead NVARCHAR(100) = CONCAT('{"sub": ', @SubAccId, ', "seen": "', FORMAT(GETDATE(),'yyyy-MM-dd hh:mm:ss'),'"}')
	UPDATE tm WITH(ROWLOCK, UPDLOCK)
	SET tm.ExtraInfo = JSON_MODIFY(ISNULL(tm.ExtraInfo,'{}'), 'append $.read', JSON_QUERY(@newRead))
	FROM dbo.ToastMessage tm
	OUTER APPLY (
		SELECT TOP 1 1 AS IsRead
		FROM OPENJSON(tm.ExtraInfo, '$.read') WITH (subAccId INT '$.sub')
		WHERE subAccId = @SubAccId
	) AS rs
	WHERE tm.TargetId = @TargetId
		AND rs.IsRead IS NULL
		AND 1 = CASE 
					WHEN @SiteFunctionName = 'Age_ADBT_Config' AND tm.ToastId <= @ToastId AND tm.SiteFunctionId IN (1,2) THEN 1 --> include FailedTransfer messages
					WHEN tm.ToastId = @ToastId THEN 1 -- single message
					ELSE 0 END

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg		= 'Invalid request.'
	END
END
GO