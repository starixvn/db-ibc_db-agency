/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="1"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_GetCustomerNetPosition]
	@CustId			INT,
	@RoleId			TINYINT
AS

/*
	Created: 20180801@Percy
	DB: DBTXN.bodb02
	Task: Get total netPosition

	Revisions:
		- 20180801@Percy: Initialize SP [RedmineID: #92142]
*/

BEGIN
	IF @RoleId = 3
	BEGIN
		SELECT np.custId, SUM(ISNULL(np.credit, 0) - ISNULL(np.debit, 0)) AS netPosition
		FROM dbo.BalNetPosition np WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON np.CustID = c.custid
		WHERE c.mrecommend = @CustId AND c.roleId = 1
		GROUP BY np.custId
	END
	ELSE IF @RoleId = 2
	BEGIN
		SELECT np.custId, SUM(ISNULL(np.credit, 0) - ISNULL(np.debit, 0)) AS netPosition
		FROM dbo.BalNetPosition np WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON np.CustID = c.custid
		WHERE c.recommend = @CustId AND c.roleId = 1
		GROUP BY np.custId
	END
END
GO