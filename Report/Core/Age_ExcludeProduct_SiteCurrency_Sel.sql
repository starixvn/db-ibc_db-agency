/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_ExcludeProduct_SiteCurrency_Sel]
	@CustId				INT = 0,
	@IsGroupHeadline	BIT = 0,
	@GroupName			VARCHAR(50) = '' -- using for External Site
AS

/*
	Created: 20181004@Percy
	DB: DBAGE.bodb02
	Task: Get Excluding ProductId by customer belong to Site/Currency

	Revisions:
		- 20181004@Percy: Initialize SP [RedmineID: #101644]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteCurrency TABLE (Site VARCHAR(10), Currency INT)

	IF @CustId <> 0
	BEGIN
		IF @IsGroupHeadline = 0
		BEGIN
			DECLARE @site VARCHAR(10), @Currency INT, @RoleId TINYINT, @recommend INT

			SELECT @Site = Site, @Currency = Currency, @RoleId = RoleId, @recommend = recommend
			FROM dbo.Customer WITH (NOLOCK)
			WHERE CustId = @CustId

			IF @RoleId = 1
				SELECT @Site = Site, @Currency = Currency
				FROM dbo.Customer WITH (NOLOCK)
				WHERE CustId = @recommend

			INSERT INTO @SiteCurrency (Site, Currency)
			VALUES (@Site, @Currency)
		END
		ELSE
		BEGIN
			DECLARE @GroupID INT 
			SELECT @GroupID = GroupID FROM custAccount WITH (NOLOCK) WHERE CustID = @CustID AND IsGroupHeadLine = 1
		
			INSERT INTO @SiteCurrency (Site, Currency)
			SELECT DISTINCT CASE WHEN c.RoleId = 1 THEN agent.Site ELSE c.Site END, c.Currency
			FROM dbo.custAccount ca WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON ca.custId = c.custId
				LEFT JOIN dbo.Customer agent WITH (NOLOCK) ON c.recommend = agent.custId AND c.roleId = 1
			WHERE ca.GroupId = @GroupId
		END
	END
	ELSE IF @GroupName <> ''
	BEGIN
		INSERT INTO @SiteCurrency (Site, Currency)
		SELECT s.Site, c.ExchangeId
		FROM
		(
			SELECT s.Site
			FROM dbo.f_SiteBySystem(@GroupName) f
				INNER JOIN dbo.Site s WITH (NOLOCK) ON f.SiteId = s.SiteId
		) AS s
			CROSS JOIN dbo.f_CurrencyBySystem(@GroupName) AS c
	END

	SELECT DISTINCT f.ProductId
	FROM dbo.f_Get_ExcludeProduct_SiteCurrency() f
		INNER JOIN @SiteCurrency sc ON f.Site = sc.Site AND f.Currency = sc.Currency
END
GO