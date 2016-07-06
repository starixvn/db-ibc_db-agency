USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[Age_CheckValidCountry_xpre]    Script Date: 7/6/2016 9:04:14 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CheckValidCountry]
	@IP NVARCHAR(15),
	@countryCode VARCHAR(2) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-11-18
		Task: Check IP from block countries	
		DB: DBCUST/CustDB
		
		Revisions:
			- 20160507@Sophia: Block users from CountryCode except Office IPs [Redmine: #60347]
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @countryLONG nvarchar(64)

	DECLARE @PrefixLoginIP NVARCHAR(11)						
	SELECT  @PrefixLoginIP = left(@IP, (len(@IP) - (charindex('.',reverse(@IP)))+1))

	IF @IP IN (select IP FROM IPDB.dbo.IPOffice WITH (NOLOCK)) -- In IP's Office then return CountryCode as 'OF'
	BEGIN 
		SELECT @CountryCode = 'OF'
	END
	ELSE 
	BEGIN 	----Not In IP's Office then keep as current
		EXEC IPDB.dbo.GetIPInfo_out @IP= @IP, @countrySHORT = @countryCode OUTPUT, @countryLONG = @countryLONG OUTPUT
	END
 
END
GO

GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CheckValidCountry] TO [bodbDownlineNetView]
GO