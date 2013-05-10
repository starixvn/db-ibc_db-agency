ALTER PROCEDURE [dbo].[Age_SelIsShownCasinoAd]
	@custid int,
	@IP nvarchar(15)='',
	@IsShown bit OUTPUT
AS
-- For showing casino ad on Agent Site from 18/8 (for ACG master only)
-- Just show for agent NOT have in ACG table

BEGIN
	Declare @srecommend int, @mrecommend int
	
	select @srecommend = srecommend, @mrecommend = mrecommend
	from customer with (nolock)
	where custid = @custid
	
	if exists(
		select 1
		from Cust_acg_master with (nolock)
		where custid = @custid or custid = @srecommend or custid = @mrecommend
		)
	BEGIN
		select @IsShown = 1
	END
	ELSE
	BEGIN
		select @IsShown = 0
	END
END

GO
GRANT EXECUTE ON [dbo].[Age_SelIsShownCasinoAd] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_SelIsShownCasinoAd] TO [bodbDownlineNetView]

