CREATE PROCEDURE [dbo].[Age_CustomerSelNewMembers]
	 @custid INT
AS
/*
	Created: Johnson
	Date: 2011-05-31
	DB: DB052.BODB02
	Task: Get new members 
*/
SET NOCOUNT ON

DECLARE @CurrentMonth		DATETIME,
		@roleid				INT	

SELECT @currentMonth = convert(varchar(10),current_timestamp,120)
SELECT @currentMonth = dateadd(day,- datepart(day,@currentMonth)+ 1,@currentMonth)

SELECT @roleid = roleid 
FROM custinfo WITH(NOLOCK)
WHERE custid = @custid

IF @roleid = 2
BEGIN	
	SELECT ci.custid, ci.username, c.creatdate, isnull(ci.credit,0) as 'credit'
	FROM customer c WITH(NOLOCK)
	INNER JOIN custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
	WHERE ci.recommend = @custid and ci.roleid = 1 and c.creatdate >= @currentMonth
	ORDER BY c.creatdate DESC	
END
ELSE IF @roleid = 3
BEGIN
	SELECT ci.custid, ci.username, c.creatdate, isnull(ci.credit,0) as 'credit'
	FROM customer c WITH(NOLOCK)
	INNER JOIN custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
	WHERE ci.mrecommend = @custid and ci.roleid = 1 and c.creatdate >= @currentMonth
	ORDER BY c.creatdate DESC
END
ELSE IF @roleid = 4
BEGIN
	SELECT ci.custid, ci.username, c.creatdate, isnull(ci.credit,0) as 'credit'
	FROM customer c WITH(NOLOCK)
	INNER JOIN custinfo ci WITH(NOLOCK) ON c.custid = ci.custid
	WHERE ci.srecommend = @custid and ci.roleid = 1 and c.creatdate >= @currentMonth
	ORDER BY c.creatdate DESC	
END




GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelNewMembers] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelNewMembers] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelNewMembers] TO [vnteam] 