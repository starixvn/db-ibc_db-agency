ALTER PROCEDURE [dbo].[Age_CustomerSelOnlineList_Ag]
 @custid INT   
/*  
 Created: Johnson  
 Date: 2011-05-31  
 DB: DB03.BODB02  
 Task: get online list and the last transaction of members under agent   

 Revisions:
	- 20110801@Lukas: change the way get last login from on_user.reload_time to customer.lastlogged
	- 20110808@Lukas: move SP to DB03.BODB02 to reduce CPU cost when call linked-server
	- 20110912@Sophia: Change table on_user_agent instead of on_user
*/  
WITH RECOMPILE  
AS  
  
  
SET NOCOUNT ON  
  
SELECT c.username, c.lastlogged as reload_time, o.IP   
FROM customer c WITH(NOLOCK)  
	INNER JOIN ON_USER.dbo.On_User_Agent o WITH(NOLOCK) ON c.custid = o.custid   
WHERE   
 c.recommend = @custid    
 AND c.roleid = 1  
 AND o.ServerID <> 0  
 AND o.iskickedout = 0  
GROUP BY c.username , c.lastlogged , o.IP  
ORDER BY c.lastlogged DESC  

	

GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelOnlineList_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelOnlineList_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelOnlineList_Ag] TO [vnteam]