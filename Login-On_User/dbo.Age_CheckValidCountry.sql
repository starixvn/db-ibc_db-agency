ALTER PROCEDURE [dbo].[Age_CheckValidCountry]
	@IP NVARCHAR(15),
	@countryCode VARCHAR(2) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-11-18
		Task: Check IP from block countries	
		DB: DBTXN/CustDB
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @countryLONG nvarchar(64)
			
	EXEC IPDB.dbo.GetIPInfo_out @IP= @IP, @countrySHORT = @countryCode OUTPUT, @countryLONG = @countryLONG OUTPUT
	
	--hardcode for testing on local
	IF @IP IN ('10.21.10.38')
		SELECT @CountryCode = 'SG'
	
END
GO

GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNetView]