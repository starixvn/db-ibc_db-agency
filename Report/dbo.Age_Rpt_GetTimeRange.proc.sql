ALTER PROCEDURE dbo.Age_Rpt_GetTimeRange (
	@RptTypeId	TINYINT		 = 0
	,@SiteName	VARCHAR(100) = ''
)
AS
/*
Created: 20140926@Bobby.Nguyen
Task: Feature #22421 - Additional disclaimer into report to indicate the available time range having data
DB:	DBAGE.bodb_Age 
Original:

Revisions:           
	-20140926@Bobby.Nguyen: Init SP
	-20141121@Bobby.Nguyen: Add Historical report time range
	
Param's Explanation: 
	- @RptTypeId: 0: All time ranges - X: specific one

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @curDate		DATE
		, @rptTypeName		VARCHAR(50)		


	DECLARE @Age_RptTimeRange AS TABLE ( 
			RptType			TINYINT
			, TypeName		VARCHAR(50)
			, StartDate		DATE
			, EndDate		DATE
		);
	DECLARE @Age_RptTimeRange_Config AS TABLE ( 
			RptType			TINYINT
			, TypeName		VARCHAR(50)
			, SValue		INT
			, SUnit			CHAR(10)
		
		);
	
	-- set current date
	SET @curDate		= GETDATE()

	--Define table structure
	/**
	1. From the latest BalanceUp date
	2. First day of previous 3 Months
	3. From 05/20/2013 (special case for report FB Financial)
	4. First date of previous 18 Months
	5. Historical report - the first date of first month of previous X Years
	**/
	INSERT INTO @Age_RptTimeRange_Config
	SELECT t.RptType
		, t.TypeName
		, t.SValue
		, t.SUnit
	FROM (
		SELECT
			1					AS RptType
			,'BalanceUp'		AS TypeName
			,0					AS SValue
			,'-'				AS SUnit
		UNION
		SELECT
			2					AS RptType
			,'Previous3Months'	AS TypeName
			,-3					AS SValue
			,'M'				AS SUnit
		UNION
		SELECT
			3					AS RptType
			,'FBFinancial'		AS TypeName
			,0					AS SValue
			,'-'				AS SUnit
		UNION
		SELECT
			4					AS RptType
			,'Previous18Months'	AS TypeName
			,-18				AS SValue
			,'M'				AS SUnit
		
		UNION
		SELECT
			5					AS RptType
			,'HistoricalReport'	AS TypeName
			,-3					AS SValue
			,'Y'				AS SUnit

	) AS t

	-- Initial time range values
	INSERT INTO @Age_RptTimeRange (
		RptType
		,TypeName
	)
	SELECT cf.RptType
		,cf.TypeName
	FROM @Age_RptTimeRange_Config cf


	-- hardcode for FBFinancial report type
	UPDATE d
	SET d.StartDate = '2013-05-20'
	FROM @Age_RptTimeRange d
	WHERE d.TypeName = 'FBFinancial'

	--search for specific one---------------------------------
	SELECT TOP 1
		@rptTypeName	= t.TypeName
	FROM @Age_RptTimeRange_Config t
	WHERE t.RptType = @rptTypeId

	--update BalanceUp time range
	IF(@rptTypeName = 'BalanceUp'
		OR @RptTypeId = 0 )
	BEGIN
		UPDATE d
		SET StartDate = t.BalanceDate
		FROM @Age_RptTimeRange d
		CROSS APPLY (
			SELECT TOP 1 
				bt.winlostdate	AS BalanceDate
			FROM bodb02.dbo.Bettrans bt WITH(NOLOCK)  
			WHERE bt.bettype	= 20000 
				AND bt.matchid	= 0 
				AND bt.custid	= 3  
		) t
		WHERE d.TypeName IN ('BalanceUp')

	END

	--update Previous Months/Years time range
	IF(@rptTypeName IN ('Previous3Months', 'Previous18Months', 'HistoricalReport')
		OR @RptTypeId = 0 )
	BEGIN
	
		UPDATE d
		SET StartDate = t.FromDate
		FROM @Age_RptTimeRange d
		CROSS APPLY (
			SELECT TOP 1
				CASE 
					WHEN cf.SUnit = 'D' THEN DATEADD(D, cf.SValue, @curDate) 
					WHEN cf.SUnit = 'M' THEN DATEADD(M, cf.SValue, DATEADD(M, DATEDIFF(M, 0, @curDate), 0))
					WHEN cf.SUnit = 'Y' THEN DATEADD(YEAR, cf.SValue, DATEADD(YEAR, DATEDIFF(YEAR, -1, @curDate), 0)) -- -1: count current year
					ELSE @curDate
				END	AS FromDate
			FROM @Age_RptTimeRange_Config cf
			WHERE cf.RptType = d.RptType
		) t
		WHERE d.TypeName = @rptTypeName
			OR (@rptTypeId = 0 AND d.TypeName IN ('Previous3Months', 'Previous18Months', 'HistoricalReport') )
	END

	--return to time range
	SELECT d.RptType
		, d.TypeName
		, d.StartDate
		, d.EndDate
	FROM @Age_RptTimeRange d
	WHERE d.RptType 	= @rptTypeId
		OR @rptTypeId 	= 0

	RETURN;
END
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_GetTimeRange] TO [BODBDownlineNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Age_Rpt_GetTimeRange] TO [BODBDownlineNetView] AS [dbo]
GO

