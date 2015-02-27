ALTER PROCEDURE [dbo].[Age_CheckValidDDate]
	@IP NVARCHAR(15) = ''
	,@Site NVARCHAR(20) = ''
	,@DDate DATETIME = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 2015-01-15
	Task: Check DDate by site or IP
	DB: DBTXN/CustDB
		
	Revisions:
		
	Parameter's Explanation:

	Example:	DECLARE @DDate DATETIME
				EXEC Age_CheckValidDDate @IP = '10.21.10.31', @DDate = @DDate OUTPUT
				--EXEC Age_CheckValidDDate @Site ='733333', @DDate = @DDate OUTPUT
				SELECT @DDate
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @Temp TABLE (CountryCode VARCHAR(2), Site NVARCHAR(20), DDate DATETIME)
	DECLARE @CountryLONG NVARCHAR(64), @CountryCode VARCHAR(2)
	
	INSERT INTO @Temp (CountryCode, Site, DDate)
	SELECT 'US', 'BEST-ODDS', '2015-01-15'
	UNION ALL 
	SELECT 'UK', '733333', '2015-01-20'
	UNION ALL 
	SELECT 'GE', '033333', '2015-01-25'
	UNION ALL 
	SELECT 'TW', '789y', '2015-02-01'
	UNION ALL --hardcode for testing on local
	SELECT 'SG', 'OLE777', '2015-01-16'

	IF @IP <> ''
	BEGIN
		EXEC IPDB.dbo.GetIPInfo_out @IP= @IP, @countrySHORT = @CountryCode OUTPUT, @CountryLONG = @CountryLONG OUTPUT
	
		--hardcode for testing on local
		IF @IP IN ('10.21.10.38','10.21.10.31')
			SELECT @CountryCode = 'SG'
		
		SELECT @DDate = DDate FROM @Temp WHERE CountryCode = @CountryCode
	END
	IF @Site <> ''
	BEGIN
		SELECT @DDate = DDate FROM @Temp WHERE Site = @Site
	END	
END
GO

GRANT EXECUTE ON [dbo].[Age_CheckValidDDate] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CheckValidDDate] TO [bodbDownlineNetView]