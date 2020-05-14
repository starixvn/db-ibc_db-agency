/*<info serverAlias="DBAGE-bodb_AGE" executers="bodbAdminNet" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_Banner_Select
(
	@FilterBy TINYINT = 1,
	@FromDate DATETIME,
	@ToDate DATETIME,
	@Environments VARCHAR(200),
	@Systems VARCHAR(200)
)
AS
/*
	Created: 20200504@Sol
	Task : Promotional Banner
	DB: DBAGE-bodb_AGE
	
	Revisions:
		- 20200504@Sol: get list banner [Redmine:#132813]

	Params info:
		@FilterBy: 
			1 = filter by ReleasedDate
			2 = filter by ExpirationDate
			3 = filter by CreatedDate
	
*/
BEGIN
	
	SET NOCOUNT ON

	;WITH rs AS 
	(
		SELECT DISTINCT bm.BannerId, bm.BannerName, bm.IsActive, bm.ReleasedDate, bm.ExpirationDate, bm.Environments, bm.Systems, bm.CreatedDate, bi.Type as TypeofBanner
				, STUFF((
							SELECT ', ' + innBi.LanguageCode
							FROM Age_BannerImage innBi
							WHERE bi.BannerId = innBi.BannerId AND bi.Type = innBi.Type
								and innbi.ImageContent is not null
							FOR XML PATH('')
						), 1, 1, '') AS LanguageCode
		FROM Age_BannerManagement bm WITH(NOLOCK)
			INNER JOIN Age_BannerImage bi WITH(NOLOCK)
				ON bm.BannerId = bi.BannerId
		WHERE 1 = CASE WHEN @FilterBy = 1 AND ((bm.ReleasedDate BETWEEN @FromDate AND @ToDate) OR bm.ReleasedDate IS NULL) THEN 1
						WHEN @FilterBy = 2 AND ((bm.ExpirationDate BETWEEN @FromDate AND @ToDate) OR bm.ExpirationDate IS NULL) THEN 1
						WHEN @FilterBy = 3 AND bm.CreatedDate BETWEEN @FromDate AND @ToDate THEN 1
						ELSE 0
					END
			AND (CHARINDEX(@Environments, bm.Environments, 0) > 0 OR ISNULL(@Environments, '') = '')
			AND (CHARINDEX(@Systems, bm.Systems, 0) > 0 OR ISNULL(@Systems, '') = '')
	) 
	SELECT BannerId, BannerName, IsActive, ReleasedDate, ExpirationDate, Environments, Systems, CreatedDate
			, MAX(CASE WHEN TypeofBanner = 1 THEN LanguageCode END) AS Desktop
			, MAX(CASE WHEN TypeofBanner = 2 THEN LanguageCode END) AS Mobile
	FROM rs 
	GROUP BY BannerId, BannerName, IsActive, ReleasedDate, ExpirationDate, Environments, Systems, CreatedDate

END
GO