/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_MemCommission_SelBettype]  
	@custID INT = 0 -- default: site MBC
AS

/*  
 Task: Get bet types for Member Commission function  
 Date: 20150410@Tom.Vo
 DB: DBAGE/bodb02   
 Revisions:
	- 20150519@Sophia: Support Metric Gaming [#35278]
	- 20151207@Percy: Add new 4 bettypes Over/Under into comm1 section [Redmine: #48050]
	- 20160218@Percy: Add new bettypes of Cricket [Redmine: #50027]
	- 20160711@Helen: Change Moneyline Commission [Redmine: #58493]
	- 20170410@Percy:
		1. Add new bettypes of BAIO [RedmineID: #74558]
		2. Remove 2 excess bettypes 807, 808 [RedmineID: #56344]
	- 20170425@Percy: Use related bettype - commission group function [RedmineID: #71665]
	- 20190816@Percy: Apply primary-secondary bettype [RedmineID: #117068]
*/

BEGIN

	SET NOCOUNT ON
	
	DECLARE @isIMBC BIT = 0

	IF ISNULL(@CustID, 0) <> 0
	BEGIN
		IF (
				SELECT [Site]
				FROM DBCUST.CustDB.dbo.Customer WITH (NOLOCK)
				WHERE custid = @CustID
				) = 'IMBC'
			SELECT @isIMBC = 1
	END

	SELECT CommGroup AS CommID
		,STUFF((
				SELECT ',' + CONVERT(VARCHAR(10), bettype)
				FROM f_Bettype_CommGroup() bc
				WHERE bc.CommGroup = c.CommGroup
					AND (
						@isIMBC = 0
						OR bc.bettype <> 501
						)
					AND bc.isShow = 1
					AND NOT EXISTS (SELECT 1 FROM dbo.f_GroupBettype() g WHERE bc.bettype = g.Bettype AND g.Bettype <> g.GroupTypeId)
				FOR XML PATH('')
				), 1, 1, '') AS typeid
		,CommGroup AS OrderID
	FROM dbo.f_Bettype_CommGroup() c
	WHERE CommGroup IN (1,2)
	GROUP BY CommGroup
	ORDER BY CommGroup
END
GO