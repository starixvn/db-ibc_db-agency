/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_xnap,wsv_alp,wsv_nap,wsv_alpv,asv_CashService" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ToastMessage_Ins]
	@TargetId			INT,
	@TypeId				TINYINT,
	@SiteFunctionId		TINYINT,
	@Creator			INT,
	@Content_en			NVARCHAR(4000) = NULL,
	@Content_ch			NVARCHAR(4000) = NULL,
	@Content_cs			NVARCHAR(4000) = NULL,
	@Content_jp			NVARCHAR(4000) = NULL,
	@Content_ko			NVARCHAR(4000) = NULL,
	@Content_it			NVARCHAR(4000) = NULL,
	@Content_th			NVARCHAR(4000) = NULL,
	@Content_es			NVARCHAR(4000) = NULL,
	@Content_vn			NVARCHAR(4000) = NULL,
	@Content_id			NVARCHAR(4000) = NULL,
	@Content_el			NVARCHAR(4000) = NULL,
	@Content_mx			NVARCHAR(4000) = NULL,
    @ToastId            INT = 0 OUTPUT,
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20230831@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBMSG-bodb_Message

	Revisions:
		- 20230831@Bobby: AutoJob clear balance downlines - Notice message [RedmineID: #182071]
        - 20231101@Bobby: Enhance TransferOption config [RedmineID: #195135]

	Param's Explanation:
		• @PairOfBatch: The number pairs of batch

*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @CreatedTime    DATETIME,
        @ExpireTime         DATETIME,
	    @TypeName		    VARCHAR(100),
	    @SiteFunctionName	VARCHAR(100);

	SELECT 	@ToastId        = 0,
            @ErrCode		= 0,
			@ErrMsg			= '',
            @CreatedTime    = CURRENT_TIMESTAMP
	;

    -- TODO: CHECK validation inputs
    SELECT TOP 1 @TypeName = TypeName  
    FROM dbo.ToastType WITH(NOLOCK) 
    WHERE TypeId = @TypeId;

    IF @TypeName IS NULL
    BEGIN
        SELECT @ErrCode = 101,
			@ErrMsg = 'Input is invalid.'
    END

    SELECT TOP 1 @SiteFunctionName = SiteFunctionName 
    FROM dbo.ToastSiteFunction WITH(NOLOCK) 
    WHERE SiteFunctionId = @SiteFunctionId;

    IF @SiteFunctionName IS NULL
    BEGIN
        SELECT @ErrCode = 102,
			@ErrMsg = 'Input is invalid.'
    END

    SELECT @ExpireTime = CASE 
                            WHEN @SiteFunctionName = 'Age_AutoTransfer_Failed' THEN DATEADD(SECOND, -1, CAST(DATEADD(DAY, 1, CAST(@CreatedTime AS DATE)) AS DATETIME))
                            ELSE @ExpireTime 
                           END

	--TODO: Check line completed with Failed cases
    BEGIN TRY
	    INSERT INTO [dbo].[ToastMessage]
           ([TargetId]
           ,[TypeId]
           ,[SiteFunctionId]
           ,[Content_en]
           ,[Content_ch]
           ,[Content_cs]
           ,[Content_jp]
           ,[Content_it]
           ,[Content_th]
           ,[Content_ko]
           ,[Content_es]
           ,[Content_vn]
           ,[Content_id]
           ,[Content_el]
           ,[Content_mx]
           ,[Creator]
           ,[CreatedTime]
           ,[ExpireTime])
        VALUES
           (@TargetId
           ,@TypeId
           ,@SiteFunctionId
           ,@Content_en
           ,@Content_ch
           ,@Content_cs
           ,@Content_jp
           ,@Content_it
           ,@Content_th
           ,@Content_ko
           ,@Content_es
           ,@Content_vn
           ,@Content_id
           ,@Content_el
           ,@Content_mx
           ,@Creator
           ,@CreatedTime
           ,@ExpireTime
        );
        SET @ToastId = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        SELECT @ErrCode = 103,
			@ErrMsg = ERROR_MESSAGE()
    END CATCH
END
GO