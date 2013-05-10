
CREATE PROCEDURE [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency]
	@CustID INT
AS
/*
Created: Sophia
Date: 2011-07-20
Task : List data for combo currency of Consolidated Report
DB: DBAGE/bodb_AGE
Original:  

Revisions:    
	- 20130121@Dan: Move sp from DB053/bodb02 to DBAGE/bodb_AGE
Param's Explanation:

*/

SET NOCOUNT ON

DECLARE @TmpCustID TABLE(CustID INT, RoleID INT )

	INSERT INTO @TmpCustID
	SELECT	B.CustID , B.RoleID
	FROM	Age_CustGroup A WITH (NOLOCK) 
	INNER JOIN Age_CustGroup B WITH (NOLOCK)ON A.GroupID = B.GroupID
	WHERE	A.CustID = @CustID AND A.isHeader = 1


	SELECT	DISTINCT C.Currency, E.currency as CurrencyName, E.actualrate as RMRate, E.US$Rate as USRate
	FROM	bodb02.dbo.Customer C WITH (NOLOCK)
	INNER JOIN @TmpCustID T 
			ON T.CustID = C.CustID
	INNER JOIN bodb02.dbo.exchange E
			ON E.exchangeid = C.currency





GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Rpt_ConsolidatedGroupSelCurrency] TO [vnteam]
