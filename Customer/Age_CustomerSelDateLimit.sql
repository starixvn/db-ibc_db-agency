/*<info serverAlias="DBAGE-bodb_AGE" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0"></info>*/
USE bodb_Age
GO

CREATE PROCEDURE [dbo].[Age_CustomerSelDateLimit] @custId INT
AS
/*
	Created: 20180426@Razor
	DB: DBAGE/bodb_AGE
	Task: 

	Revisions:
		-20180427@Razor: init - [Readmine: #93852]
		
	Param's Explanation:		
		• @custId: the ID of customer.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CurrentDate SMALLDATETIME	
	SET @CurrentDate = CAST(GETDATE() AS DATE)
	
	SELECT ISNULL(MinDate, DATEADD(day, - 1 * LimitDays, @CurrentDate)) AS DateLimit
	FROM dbo.Age_CustDateLimit l WITH (NOLOCK)
		INNER JOIN bodb02.dbo.custInfo c WITH (NOLOCK) ON l.CustId = c.srecommend
	WHERE c.custId = @custId
END
GO