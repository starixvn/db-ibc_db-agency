ALTER PROCEDURE Age_Monitor_CustListBy_Ag
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
WHERE c.recommend = @CustID

GO
GRANT EXECUTE ON [dbo].Age_Monitor_CustListBy_Ag TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Monitor_CustListBy_Ag TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].Age_Monitor_CustListBy_Ag TO [vnteam]
GO