/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet,wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_Monitor]
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@bobby: INIT [RedmineID: #182071]
		- 20240202@Luke: Enhance Auto Transfer Phase 3 [Redmine: #195551]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @SessionDate SMALLDATETIME;

	SELECT @SessionDate = CAST(GETDATE() AS DATE),
		@ErrCode		= 0,
		@ErrMsg			= ''
	;

	SELECT TOP(1)
		@ErrCode		= 101,
		@ErrMsg			= CONCAT('Hey guys, the item on process auto transfer clear balance on server (', @@SERVERNAME ,', Env=', Environment, ') has been running for too long time (table Age_ClearBalanceCust_Process, ModifiedTime=', FORMAT(ModifiedTime, 'yyyy-MM-dd HH:mm:ss') ,',CURRENT_TIMESTAMP=',FORMAT(CURRENT_TIMESTAMP, 'yyyy-MM-dd HH:mm:ss'),'). Please check!!!')
	FROM dbo.Age_ClearBalanceCust_Process p WITH(ROWLOCK)
	WHERE SessionDate = @SessionDate
		AND p.Status IN ('Waiting', 'Processing', 'Pending', 'Exception')
		AND DATEDIFF(MINUTE, p.ModifiedTime, CURRENT_TIMESTAMP) > 15 --> long running since 15 minutes

	IF @ErrCode > 0
	BEGIN
		EXECUTE	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@SERVERNAME
			, @JobId = NULL, @JobName = N'vndba:Check slowly running or failed processes'
			, @Message = @ErrMsg
			, @CaseId = 1;
	END
END
GO