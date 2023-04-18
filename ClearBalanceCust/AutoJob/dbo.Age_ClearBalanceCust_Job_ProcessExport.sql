/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_ClearBalanceCust_Job_ProcessExport]
	@PageSize				INT = 5000
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
		@RowData		VARCHAR(MAX),
		@TotalRow		INT
	;

	SELECT @today		= GETDATE(),
		@TotalRow		= 0
	;

	SELECT @TotalRow = COUNT(1)
	FROM bodb02.dbo.Age_ClearBalanceCust_Process p WITH(NOLOCK)
	WHERE p.SessionDate = @today
	;

	WITH CTE_Paging AS
	(
		SELECT 1 AS PageIndex
		UNION ALL
		SELECT PageIndex = PageIndex + 1
		FROM CTE_Paging
		WHERE PageIndex < ((@TotalRow/@PageSize) + 1)
	)
	SELECT p.PageIndex, r.RowData, @TotalRow AS TotalRow
	FROM CTE_Paging p
	CROSS APPLY (
		SELECT RowData = (
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
			OFFSET ((p.PageIndex-1)*@PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
			FOR JSON PATH)
	) AS r
	WHERE r.RowData IS NOT NULL
	OPTION (MAXRECURSION 1000)
END
GO
