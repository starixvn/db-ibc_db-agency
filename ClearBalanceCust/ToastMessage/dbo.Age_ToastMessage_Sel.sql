/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ToastMessage_Sel]
	@TargetId			INT = 0,
	@SubAccId			INT = NULL,
	@Language			VARCHAR(2) = 'E',
	@LastToastId		INT = 0
AS
/*
	Created: 20230831@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBMSG-bodb_Message

	Revisions:
		- 20230831@Bobby: AutoJob clear balance downlines - Notice message [RedmineID: #182071]
		- 20240924@Lewis: Deployed SIT [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @PostTime DATETIME;
	
	SELECT @PostTime	= GETDATE(),
		@SubAccId		= ISNULL(@SubAccId, 0)
	;

	--TODO: Get toast message by TargetId
	SELECT 
		tm.ToastId
		, tt.TypeId
		, tf.SiteFunctionId
		, ck.Content
		, tm.CreatedTime
	FROM [dbo].[ToastMessage] tm WITH(NOLOCK)
		INNER JOIN dbo.ToastType tt WITH(NOLOCK) ON tt.TypeId = tm.TypeId
		INNER JOIN dbo.ToastSiteFunction tf WITH(NOLOCK) ON tf.SiteFunctionId = tm.SiteFunctionId
		CROSS APPLY (
			SELECT 
					CASE @Language 
						WHEN 'CS'	THEN Content_cs
						WHEN 'CT'	THEN Content_ch
						WHEN 'TH'	THEN Content_th
					ELSE tm.Content_en
				END
		) AS ck (Content)
		OUTER APPLY (
			SELECT TOP 1 1 AS IsRead
			FROM OPENJSON(tm.ExtraInfo, '$.read') WITH (subAccId INT '$.sub')
			WHERE subAccId = @subAccId  -- sub acc
		) AS rs
	WHERE tm.TargetId = @TargetId -- main acc
		AND tm.ToastId > @LastToastId
		AND rs.IsRead IS NULL
		AND 1 = CASE 
					WHEN tf.SiteFunctionName = 'Age_AutoTransfer_Failed' AND @PostTime > tm.ExpireTime THEN 0 
				ELSE 1 END
	ORDER BY tm.TargetId DESC
	;
END
GO