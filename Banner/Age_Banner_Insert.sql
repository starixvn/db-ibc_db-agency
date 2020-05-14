/*<info serverAlias="DBAGE-bodb_AGE" executers="bodbAdminNet" viewers="" isFunction="0" isNested=""></info>*/
CREATE PROCEDURE [dbo].[Age_Banner_Insert]
(
	@BannerName		VARCHAR(500),
	@IsActive		BIT,
	@ReleasedDate	DATETIME,
	@ExpirationDate	DATETIME,
	@Environments	VARCHAR(200) = NULL,
	@Systems		VARCHAR(200) = NULL,
	@Creator		INT = 0,
	@DeskEnUsImage 	VARBINARY(MAX) = NULL,
	@DeskViVnImage 	VARBINARY(MAX) = NULL,
	@DeskZhCnImage 	VARBINARY(MAX) = NULL,
	@DeskZhTwImage 	VARBINARY(MAX) = NULL,
	@DeskThThImage 	VARBINARY(MAX) = NULL,
	@DeskKoKrImage 	VARBINARY(MAX) = NULL,
	@DeskJaJpImage 	VARBINARY(MAX) = NULL,
	@MobileEnUsImage 	VARBINARY(MAX) = NULL,
	@MobileViVnImage 	VARBINARY(MAX) = NULL,
	@MobileZhCnImage 	VARBINARY(MAX) = NULL,
	@MobileZhTwImage 	VARBINARY(MAX) = NULL,
	@MobileThThImage 	VARBINARY(MAX) = NULL,
	@MobileKoKrImage 	VARBINARY(MAX) = NULL,
	@MobileJaJpImage 	VARBINARY(MAX) = NULL,
	@MobileBackgroundColor VARCHAR(10) = '',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			VARCHAR(200) = '' OUTPUT
)
AS
/*
	Created: 20200504@Sol
	Task : Promotional Banner
	DB: DBAGE-bodb_AGE
	
	Revisions:
		- 20200504@Sol: Insert new banner [Redmine:#132813]
	
*/
BEGIN

	SET NOCOUNT ON

	BEGIN TRY

		-- insert new banner 
		DECLARE @BannerManagement TABLE (BannerId INT)
		
		INSERT INTO dbo.Age_BannerManagement
				   (BannerName, IsActive ,ReleasedDate, ExpirationDate, Environments, Systems, MobileBackgroundColor, CreatedDate, Creator)
				   OUTPUT INSERTED.BannerId INTO @BannerManagement
				VALUES	
				   (@BannerName, @IsActive, @ReleasedDate, @ExpirationDate, @Environments, @Systems, @MobileBackgroundColor, GETDATE(), @Creator)

		-- insert banner image
		DECLARE @BannerId INT
		SELECT TOP 1 @BannerId = BannerId FROM @BannerManagement

		INSERT INTO dbo.Age_BannerImage
					(BannerId, [Type], LanguageCode, ImageContent)
				VALUES
					-- desktop image
					(@BannerId, 1, 'EN-US', @DeskEnUsImage),
					(@BannerId, 1, 'VI-VN', @DeskViVnImage),
					(@BannerId, 1, 'ZH-CN', @DeskZhCnImage),
					(@BannerId, 1, 'ZH-TW', @DeskZhTwImage),
					(@BannerId, 1, 'TH-TH', @DeskThThImage),
					(@BannerId, 1, 'KO-KR', @DeskKoKrImage),
					(@BannerId, 1, 'JA-JP', @DeskJaJpImage),
					-- mobile image
					(@BannerId, 2, 'EN-US', @MobileEnUsImage),
					(@BannerId, 2, 'VI-VN', @MobileViVnImage),
					(@BannerId, 2, 'ZH-CN', @MobileZhCnImage),
					(@BannerId, 2, 'ZH-TW', @MobileZhTwImage),
					(@BannerId, 2, 'TH-TH', @MobileThThImage),
					(@BannerId, 2, 'KO-KR', @MobileKoKrImage),
					(@BannerId, 2, 'JA-JP', @MobileJaJpImage)

	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = 'Error! Error when inserting banner.', @ErrCode = 101
		RETURN
	END CATCH
END

GO