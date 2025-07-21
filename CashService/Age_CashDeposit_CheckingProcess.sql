/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashDeposit_CheckingProcess
(
	@TransId BIGINT,
	@IsRelease BIT = 0,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT
)
AS
/*
	Created: 20250611@Max		
	Task: Alpha - Agency Cash Service [redmine: #223896] 
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250611@Max: Alpha - Agency Cash Service - Sprint 4 [redmine: #223896] 
		- 20250624@Eden: Alpha - Agency Cash Service - Sprint 5 [redmine: #223896] 

	Parameter's Explanation:	
*/ 
BEGIN
    SET NOCOUNT ON;

	SELECT @ErrCode			= 0
		, @ErrMsg			= ''

	IF @IsRelease = 0
	BEGIN
		IF (SELECT CASE WHEN JSON_VALUE(c.ExtraInfo, '$.IsProcessing') = 1 
						AND DATEDIFF(SECOND, TRY_CAST(JSON_VALUE(c.ExtraInfo, '$.ProcessingDate') AS DATETIME), GETDATE()) <= 120
					THEN 1 ELSE 0 END
			FROM dbo.CashTransaction c WITH (NOLOCK) 
			WHERE c.TransId = @TransId
		) = 1
		BEGIN
			SELECT @ErrCode = 409, @ErrMsg = 'The transaction inserted failed. Please try again.'
			RETURN
		END
		ELSE
		BEGIN
			UPDATE c 
			SET c.ExtraInfo = JSON_MODIFY(
					JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.IsProcessing',1),
					'$.ProcessingDate', CONVERT(VARCHAR(23), GETDATE(), 121)
				)
				,RepUpdateTime = SYSDATETIME()
			FROM dbo.CashTransaction c WITH (ROWLOCK, UPDLOCK)
			WHERE c.TransId = @TransId
		END 
	END
	ELSE IF @IsRelease = 1
	BEGIN
		UPDATE c 
		SET c.ExtraInfo = JSON_MODIFY(
				JSON_MODIFY(ISNULL(c.ExtraInfo,'{}'), '$.IsProcessing',NULL),
				'$.ProcessingDate', NULL
			)
			,RepUpdateTime = SYSDATETIME()
		FROM dbo.CashTransaction c WITH (ROWLOCK, UPDLOCK)
		WHERE c.TransId = @TransId
	END
END;