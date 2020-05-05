/*<info serverAlias="DBAGE-bodb_AGE"></info>*/
CREATE TABLE [dbo].Age_BannerImage(
	BannerImageId			INT IDENTITY(1,1) NOT NULL,
	BannerId				INT NOT NULL,
	[Type]					TINYINT NOT NULL,
	LanguageCode			VARCHAR(10) NOT NULL,
	ImageContent			VARBINARY(MAX) NULL
CONSTRAINT [PK_BannerImage] PRIMARY KEY CLUSTERED 
(
	BannerImageId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON ageIndex
) ON ageTable

GO