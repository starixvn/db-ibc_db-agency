USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_PlayForFun_MemberRequest]
	@CustId INT
AS

/*
	Creator: Percy
	Date: 2017-03-20
	DB: DBACC.bodb02
	Task: Select member request
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @srecommend INT, @RoleId TINYINT
	SELECT  @srecommend = srecommend, @RoleId = roleid FROM dbo.custInfo WITH(NOLOCK) WHERE custid = @CustId

	DECLARE @SportBettype TABLE (ProductId INT, ProductName VARCHAR(50), Sporttype INT, Bettype INT)
	INSERT INTO @SportBettype (ProductId, ProductName, Sporttype, Bettype)
	VALUES (6, 'Casino', 208, 0)

	SELECT sb.ProductId, sb.ProductName, COUNT(DISTINCT crg.CustID) AS NoOfRequest
	FROM dbo.CustRequestGame crg WITH(NOLOCK)
		INNER JOIN @SportBettype sb ON crg.Sporttype = sb.Sporttype AND crg.Bettype = sb.Bettype
	WHERE crg.isActive = 1
		AND EXISTS (
			SELECT 1 FROM dbo.custInfo c WITH(NOLOCK)
			WHERE c.custid = crg.CustID
				AND c.srecommend = @srecommend
				AND c.roleid = 1
				AND (
					@RoleId = 4
					OR (@RoleId = 3 AND c.mrecommend = @CustId)
					OR (@RoleId = 2 AND c.recommend = @CustId)
				)
				AND c.DisableCasino = 1 -- RNG Casino
		)
	GROUP BY sb.ProductId, sb.ProductName
END
GO
GRANT EXECUTE ON [dbo].[Age_PlayForFun_MemberRequest] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_PlayForFun_MemberRequest] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_PlayForFun_MemberRequest] TO [vnteam] AS [dbo]
GO