ALTER PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency_xpre]
	@CustID INT
AS
/*
	Created: Elodie
	Date: 2013-06-12
	Task : List data for combo currency of Consolidated Report
	DB: DBAGE/bodb02
	Original:  

	Revisions:    
	
	Param's Explanation:

*/

SET NOCOUNT ON

DECLARE @TmpCustID TABLE(CustID INT)

INSERT INTO @TmpCustID
SELECT	B.CustID
FROM	custAccount A WITH (NOLOCK) 
INNER JOIN custAccount B WITH (NOLOCK)ON A.GroupID = B.GroupID
WHERE	A.CustID = @CustID AND A.IsGroupHeadLine = 1 and A.IsRptConsol = 1

SELECT	DISTINCT C.Currency, E.currency as CurrencyName, E.actualrate as RMRate, E.US$Rate as USRate
FROM	Customer C WITH (NOLOCK)
INNER JOIN @TmpCustID T 
		ON T.CustID = C.CustID
INNER JOIN exchange E
		ON E.exchangeid = C.currency

GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [vnteam]
