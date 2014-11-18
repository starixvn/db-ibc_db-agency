ALTER PROCEDURE [dbo].[Age_CheckValidCountry]
	@IP NVARCHAR(15),
	@isValid BIT = 1 OUTPUT
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
	
	DECLARE @countrySHORT nvarchar(2),
			@countryLONG nvarchar(64)
	
	SET @isValid = 1
	
	EXEC IPDB.dbo.GetIPInfo_out @IP= @IP, @countrySHORT = @countrySHORT OUTPUT, @countryLONG = @countryLONG OUTPUT
	
	IF @countrySHORT = 'SG'
		SELECT @isValid = 0
	
END
GO

GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNetView]