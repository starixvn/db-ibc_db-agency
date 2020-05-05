/*<info serverAlias="DBAGE-bodb_AGE"></info>*/
CREATE TABLE [dbo].Age_BannerManagement(
	BannerId		INT IDENTITY(1,1) NOT NULL,
	BannerName		VARCHAR(500) NOT NULL,
	IsActive		BIT NOT NULL,
	ReleasedDate	DATETIME NULL,
	ExpirationDate	DATETIME NULL,
	Environments	VARCHAR(200) NULL,
	Systems			VARCHAR(200) NULL,
	MobileBackgroundColor	VARCHAR(10) NULL,
	CreatedDate		DATETIME NULL,
	Creator			INT NULL
CONSTRAINT [PK_BannerManagement] PRIMARY KEY CLUSTERED 
(
	BannerId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON ageIndex
) ON ageTable

GO