/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_ProcessExport]
	@PageIndex				INT = 1,
	@PageSize				INT = 5000,
	@TotalRow				INT = 0 OUTPUT
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

	DECLARE @today		DATE,
		@RowData		VARCHAR(MAX)
	;

	SELECT @today		= GETDATE(),
		@TotalRow		= 0
	;

	SELECT @TotalRow = COUNT(1)
	FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
	WHERE p.SessionDate = @today
	;
	
	IF @TotalRow > 0
		SELECT @RowData = (
			SELECT SessionDate	AS 'c1',
				BatchNo			AS 'c2',
				SuperId			AS 'c3',
				FromCustId		AS 'c4',
				ToCustId		AS 'c5',
				RoleId			AS 'c6',
				Status			AS 'c7',	
				Amount			AS 'c8',	
				Result			AS 'c9',	
				TryCount		AS 'c10',	
				ModifiedTime	AS 'c11',	
				StartTime		AS 'c12',	
				EndTime			AS 'c13',	
				Creator			AS 'c14',	
				IsAllDayBalTransfer		AS 'c15'
			FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
			WHERE p.SessionDate = @today
			ORDER BY BatchNo, SuperId
			OFFSET ((@PageIndex-1)*@PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
			FOR JSON PATH
		);
	
	SELECT @RowData AS RowData

END
GO
