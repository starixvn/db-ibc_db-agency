/*<info serverAlias="DBAGE-bodb_AGE" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_Banner_SelectRandomBanner
(
	@LanguageCode VARCHAR(10),
	@Environments VARCHAR(200),
	@Systems VARCHAR(200),
	@Type TINYINT
)
AS
/*
	Created: 20200504@Sol
	Task : Promotional Banner
	DB: DBAGE-bodb_AGE
	
	Revisions:
		- 20200504@Sol: get random banner [Redmine:#132813]
	
*/
BEGIN
	
	SET NOCOUNT ON
	
	SELECT TOP 1 bi.ImageContent, bm.MobileBackgroundColor
	FROM Age_BannerManagement bm WITH(NOLOCK)
		INNER JOIN Age_BannerImage bi WITH(NOLOCK)
			ON bm.BannerId = bi.BannerId
	WHERE bm.IsActive = 1
		AND CHARINDEX(@Environments, bm.Environments, 0) > 0
		AND CHARINDEX(@Systems, bm.Systems, 0) > 0
		AND bi.LanguageCode = @LanguageCode
		AND bi.[Type] = @Type
		AND 1 = CASE WHEN ISNULL(ExpirationDate, '') = '' THEN 1 
					WHEN ISNULL(ReleasedDate, '') <> '' AND GETDATE() BETWEEN bm.ReleasedDate AND bm.ExpirationDate THEN 1
					ELSE 0
				END
		AND bi.ImageContent IS NOT NULL
	ORDER BY NEWID()

END
GO