/*<info serverAlias="DBTXN-bodb02" executers="bodbDownlineNet" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_ConvertIPv6ToDummy]
(
	@IP nvarchar(15)=''
)
RETURNS NVARCHAR(15)
AS
/*
Created: 20200929@Danny
Task :  Convert IPV6 to dummy Ipv4
DB: DBTXN/bodb02
Original:

	Revisions:
		- 20200929@Danny: Convert IPV6 to dummy Ipv4 [Redmine: #142511]
*/
BEGIN
	RETURN CASE WHEN ISNUMERIC(REPLACE(@IP, '.', '')) = 0 AND @IP <> '' THEN '198.51.100.10' ELSE @IP  END
END