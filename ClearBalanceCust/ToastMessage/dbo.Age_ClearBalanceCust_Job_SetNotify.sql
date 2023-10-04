/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Age_ClearBalanceCust_Job_SetNotify]
	@TargetIds	VARCHAR(4000),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20230831@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230831@Bobby: AutoJob clear balance downlines - Notice message [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT @ErrCode		= 0,
		@ErrMsg			= '';

	--TODO: update IsSyncNotice completed with Failed cases
	BEGIN TRY
		WITH CTE_FromCustId AS (
			SELECT DISTINCT value AS FromCustId
			FROM STRING_SPLIT(@TargetIds, ',')	
		)
		UPDATE p WITH(ROWLOCK, UPDLOCK)
			SET p.IsSyncNotice = 1
		FROM dbo.Age_ClearBalanceCust_Process p
				INNER JOIN CTE_FromCustId tr ON tr.FromCustId = p.FromCustId
			WHERE 
				p.[Status] = 'Failed'
				AND p.IsSyncNotice = 0
		;
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101,
			@ErrMsg = ERROR_MESSAGE()
	END CATCH

END
GO