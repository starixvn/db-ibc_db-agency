ALTER PROCEDURE [dbo].Age_CustAccountSelTransactionByDate_DELETED ALREADY
	@custid INT=null,
	@fromdate DATETIME,
	@todate DATETIME,
	@username varchar(50) = NULL -- for API
AS
--Original SP: CustaccountSelTransactionByDate
--AGENT SITE
--UPDATED 02/22/2006: remove refno
--update@phuc 2007/12/11 for API
SET NOCOUNT ON

if @custid is null
	select @custid = custid from customer with (nolock) where username = @username

	SELECT 
		transdate, 
		refno as transcode, 
		transid as refno, 
		transdesc, 
		case when bettype <99 then 'BET' when bettype=99 then 'BAL' when bettype=101 then 'DEP' when bettype=102 then 'WIT' when bettype=103 then 'TRA' when bettype=104 then 'TRA' end as transtype, 
		actual_stake as debitamt,
		winlost as creditamt,
		transid as custaccid
	FROM 
		bettrans WITH (NOLOCK)
	WHERE 
		custid=@custid AND
		transdate<=@todate AND
		transdate>=@fromdate
	order by 
		transdate



GO


GRANT  EXECUTE  ON [dbo].Age_CustAccountSelTransactionByDate  TO [bodbDownlineNet]
GO

GRANT  EXECUTE  ON [dbo].Age_CustAccountSelTransactionByDate  TO [bodbDownlineNetView]
GO



