/*<info serverAlias="DBAGE-BODB02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_CustomerSelDateLimit] @custId INT
AS
/*
	Created: 20180426@Razor
	DB: DBAGE/BODB02
	Task: 

	Revisions:
		-20180427@Razor: init - [Readmine: #93852]
		- 20181123@Helen: DB053.bodb_AGE/BODB02 & DB052.bodb_Summary Migration [Redmine: 104770]
		
	Param's Explanation:		
		• @custId: the ID of customer.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CurrentDate SMALLDATETIME	
	SET @CurrentDate = CAST(GETDATE() AS DATE)
	
	SELECT ISNULL(MinDate, DATEADD(day, - 1 * LimitDays, @CurrentDate)) AS DateLimit
	FROM dbo.Age_CustDateLimit l WITH (NOLOCK)
		INNER JOIN dbo.custInfo c WITH (NOLOCK) ON l.CustId = c.srecommend
	WHERE c.custId = @custId
END
GO