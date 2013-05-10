ALTER PROCEDURE Age_Monitor_CustListBy_SAg
	@CustID int
AS    
/*    
Created:    
Task:    
DB: DB05.bodb02    
Original: SportSelForMonitor  
    
Revisions:     
 - 20101020@Simon: Sport are running.  
*/    
    
SET NOCOUNT ON    
    
SELECT c.CustID, ci.UserName, c.HotLevel, c.isMonitor
FROM CustMonitor c with (nolock)    
	  left join CustInfo ci with (nolock) on c.CustID=ci.CustID
WHERE c.srecommend = @CustID

GO
GRANT EXECUTE ON [dbo].Age_Monitor_CustListBy_SAg TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Monitor_CustListBy_SAg TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].Age_Monitor_CustListBy_SAg TO [vnteam]
GO