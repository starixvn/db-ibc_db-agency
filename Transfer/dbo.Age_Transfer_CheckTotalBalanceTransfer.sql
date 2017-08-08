ALTER PROCEDURE  [dbo].[Age_Transfer_CheckTotalBalanceTransfer]
	@CustID                 int,
	@SuperIDsTransferTotal  varchar(200),
	@IsAllowed              bit = null OUTPUT
AS
    /*
    Created: 20090422@AnhPham
    Task: check if a account is allowed to transfer total balance
    DB: DBCUST.CustDB
    Original:
    Revisions:
		- 20150612@Kathy: Move sp from DBAGE.bodb02 to DBCUST.CustDB [Redmine:#36216]

    
    Param's Explanation:
        . @CustID:
        . @SuperIDsTransferTotal: series of super account id which is allowed to transfer total balance
        . @IsAllowed: can be 1 or 0 (1:allow; 0:not allow)
    */
BEGIN

    SET NOCOUNT ON
    
    SELECT @IsAllowed = 0
    
    IF EXISTS(
        SELECT 1 FROM custinfo (NOLOCK) 
        WHERE custid = @custid 
            AND srecommend IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@SuperIDsTransferTotal, ',')) )
        SELECT @IsAllowed = 1
        
END

GO
GRANT EXECUTE ON [dbo].[Age_Transfer_CheckTotalBalanceTransfer] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_CheckTotalBalanceTransfer] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Transfer_CheckTotalBalanceTransfer] TO [vnteam] AS [dbo]