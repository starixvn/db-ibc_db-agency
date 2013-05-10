SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[Age_CustSubSelInfo]
	@custid int,
	@subaccid int

AS

--Task :  
--DB: DB02.bodb02
--original SP: CustSubSelInfo

SET NOCOUNT ON


Select subaccid, username, firstname, lastname, isnull(closed, 0) closed, PageAccess
from custsub with (nolock)
where custid = @custid
	and subaccid = @subaccid
order by closed, username




GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[Age_CustSubSelInfo]  TO [bodbDownlineNet]
GO

GRANT  EXECUTE  ON [dbo].[Age_CustSubSelInfo]  TO [bodbDownlineNetView]
GO

