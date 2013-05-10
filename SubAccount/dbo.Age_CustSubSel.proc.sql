SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO



ALTER PROCEDURE [dbo].[Age_CustSubSel] 
	@custid int
AS
--Task: Show Sub Account on Agent site
--DB: DB52.bodb02
--original SP: CustSubSel


SET NOCOUNT ON

Select subaccid, username, firstname, lastname,createdate, isnull(closed,0) closed, PageAccess
from custsub with (nolock)
where custid = @custid
order by closed, username


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[Age_CustSubSel]  TO [bodbDownlineNet]
GO

GRANT  EXECUTE  ON [dbo].[Age_CustSubSel]  TO [bodbDownlineNetView]
GO
