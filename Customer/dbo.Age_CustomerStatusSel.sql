 ALTER PROCEDURE [dbo].[Age_CustomerStatusSel]
	@custid INT,
	@isActive BIT = 0 OUTPUT	
AS
	/*
		Created: Johnson
		Date: 2015-02-27
		Task: check status of account(sub account& main account login)
				 at currently is closed or not
		DB: DBAGE/BODB02
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	IF EXISTS (SELECT TOP (1) 1 FROM CustSub WITH(NOLOCK) WHERE subAccID = @custid)
	BEGIN
		SELECT @isActive =  CASE WHEN closed = 1 THEN 0 ELSE 1 END
		FROM CustSub WITH(NOLOCK)
		WHERE subAccID = @custid
	END
	ELSE
	BEGIN
		SELECT @isActive = CASE WHEN closed = 1 OR Enabled = 0 THEN 0 ELSE 1 END
		FROM CustInfo WITH(NOLOCK)
		WHERE custid = @custid
		
		SELECT @isActive = ISNULL(@isActive,0) 
	END
END	
GO
GRANT EXECUTE ON [dbo].[Age_CustomerStatusSel] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerStatusSel] TO [bodbDownlineNetView]