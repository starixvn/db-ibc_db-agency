/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_StatusCheck]
	@IsAllowAutoTransfer	BIT,
	@FromCustId				INT = NULL,
	@ToCustId				INT = NULL,
	@IsAutoJobRunning		BIT OUTPUT,
	@ErrCode				INT = 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000) = '' OUTPUT

AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBTXN/bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @today		DATE
		,@StatusCheck	BIT;

	SELECT @today			= GETDATE()
		, @ErrCode			= 0
		, @ErrMsg			= ''
		, @IsAutoJobRunning	= 0
		, @StatusCheck		= ISNULL(@IsAllowAutoTransfer, 0)
		;

	--TODO: Check the AutoJob is running or NOT
	SELECT @IsAutoJobRunning = ck.IsAutoJobRunning
	FROM (
		SELECT TOP 1 1 AS IsAutoJobRunning
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		WHERE @StatusCheck = 1
			AND p.SessionDate = @today
			AND (
				p.[Status] IN ('New', 'Waiting', 'Processing')
				OR (p.[Status] = 'Failed' AND p.TryCount BETWEEN 1 AND 4)
				OR (p.[Status] = 'Pending' AND p.TryCount BETWEEN 1 AND 59)
			)
		UNION ALL

		SELECT TOP 1 1
		FROM dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
		WHERE @StatusCheck = 0
			AND p.FromCustId =  @FromCustId AND p.ToCustId = @ToCustId
			AND p.SessionDate = @today
			AND (
				p.[Status] IN ('New', 'Waiting', 'Processing')
				OR ([Status] = 'Failed' AND p.TryCount BETWEEN 1 AND 4)
				OR ([Status] = 'Pending' AND p.TryCount BETWEEN 1 AND 59)
			)
	) AS ck
END
GO