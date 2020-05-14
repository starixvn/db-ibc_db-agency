/*<info serverAlias="DBAGE-bodb_AGE" executers="bodbAdminNet" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_Banner_SelectById
(
	@BannerId INT
)
AS
/*
	Created: 20200504@Sol
	Task : Promotional Banner
	DB: DBAGE-bodb_AGE
	
	Revisions:
		- 20200504@Sol: get banner by Id [Redmine:#132813]
	
*/
BEGIN
	
	SET NOCOUNT ON
	
	SELECT BannerId, BannerName, IsActive, ReleasedDate, ExpirationDate, Environments, Systems, MobileBackgroundColor
	FROM Age_BannerManagement bm WITH(NOLOCK)
	WHERE bm.BannerId = @BannerId

	SELECT BannerId, [Type], LanguageCode, ImageContent
	FROM Age_BannerImage bi WITH(NOLOCK)
	WHERE bi.BannerId = @BannerId

END
GO