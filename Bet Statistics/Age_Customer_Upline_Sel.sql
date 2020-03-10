/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Customer_Upline_Sel]
	@CustId INT
AS

/*
	Created: 20200114@Percy
	DB: DBAGE.bodb02
	Task: Alpha - Customer - Get member's uplines

	Revisions:
		- 20200114@Percy:	Initialize SP [RedmineID: #127288]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		a.custid	AS AgentId
		,a.username	AS AgentName
		,m.custid	AS MasterId
		,m.username	AS MasterName
		,s.custid	AS SuperId
		,s.username	AS SuperName
	FROM dbo.Customer c WITH (NOLOCK)
		INNER JOIN dbo.Customer a WITH (NOLOCK) ON c.recommend  = a.custid AND a.roleid = 2
		INNER JOIN dbo.Customer m WITH (NOLOCK) ON c.mrecommend = m.custid AND m.roleid = 3
		INNER JOIN dbo.Customer s WITH (NOLOCK) ON c.srecommend = s.custid AND s.roleid = 4
	WHERE c.custid = @CustId
		AND c.roleid = 1
END
GO