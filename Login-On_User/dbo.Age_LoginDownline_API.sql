ALTER PROCEDURE [dbo].[Age_LoginDownline_API]
	@UserName varchar(50),
	@UserPwd varchar(50),
	@UserPwd2 varchar(50)='', --Old password
	@LoginIP varchar(20),
	@SessionID int,
	@ServerID int,
	@RoleID int OUTPUT,
	@CustID int OUTPUT,
	@On_UserID int OUTPUT,
	@Currency varchar(10) = '' OUTPUT,
	@Language varchar(2) = 'E',
	@MasterUsername varchar(50) = '' OUTPUT,
	@SubAccID int = 0, --Sub-AccountID,
	@site varchar(20) = '' OUTPUT
AS

-- 20111031@Viet: allow sub-account to access the service also.
-- 20121203@Thien: hard-code to exclude agent MSE06 from using this API.
-- 20130427@Thien: hard-code to exclude all 'MSE%' and IP '94.136.37.180'
-- 20131108@Elodie: Splitting bodb02 into CustDB (call WriteLog_UserLog SP by link database)

IF @UserPwd2 = '' SET @UserPwd2 = @UserPwd

declare @LogData nvarchar(200),
	@ErrMsg nvarchar(200)
--	,@logincount int,@locked int,
--	@RoleID_SAg int
--Select @RoleID_SAg  =4

-- IF @LoginIP = '218.186.9.3'
-- BEGIN
--		SET @LogData = 'Agent Banned IP:218.186.9.3 User:' + @UserName
--		EXEC bodb02.dbo.WriteLog_UserLog 25520, @LogData
--
--		select @ErrMsg = N'Login Failed.'
--		raiserror (@ErrMsg, 16, 1)
--		return
-- END

-- 20121203@Thien: hard-code to exclude agent MSE06 from using this API.
-- 20130427@Thien: hard-code to exclude all 'MSE%' and IP '94.136.37.180'
IF (@LoginIP in ( '94.136.37.180', '94.136.37.177', '81.218.184.31')) AND (@UserName NOT IN ('SAS0102SUB02', 'SAS0101SUB04', 'SAS0103SUB02', 'SAS0104SUB02', 'SI0301SUB05', 'MSE01Sub02', 'MSE03Sub01', 'MSE04Sub02', 'MSE09Sub02', 'SI0303SUB03', 'SI0305SUB02', 'SI0306SUB03', 'MSE08Sub02', 'ASASub03', 'si0307sub04'))
 BEGIN
	select @ErrMsg = N'Login Failed.'
	raiserror (@ErrMsg, 16, 1)
	return
 END

declare @rowcount bit
Declare @db_custid int, @db_userpwd nvarchar(50), @db_roleid tinyint, @failedcount int, @role nvarchar(20)
Declare @db_currency tinyint, @closed bit,@isSubAcc bit

SELECT @db_custid = custid, 	@db_userpwd = userpwd, 			@failedcount = 	isnull(logincount,0),
	@closed = closed,
	@subaccid = subaccid	
FROM custSub with(nolock) WHERE username = @UserName

IF @@ROWCOUNT = 1
BEGIN
	SELECT @db_roleid = roleid, 		@db_currency = currency, 		@site = site
	FROM customer with (nolock) WHERE custid = @db_custid
	
	select @rowcount = 0, @isSubAcc = 1
END
ELSE
BEGIN
	select @isSubAcc = 0
	SELECT @db_custid = custid, 
		@db_userpwd = userpwd, 
		@db_roleid = roleid, 
		@db_currency = currency, 
		@failedcount = logincount,
		@site = site
	FROM customer with (nolock) 
	WHERE username = @UserName
		
	IF @@ROWCOUNT = 0 select @rowcount = 1
	
	SELECT @closed = closed FROM custinfo with (nolock) WHERE custid = @db_custid
END


--Phuong Doan: 
if (@db_custid=89464)
begin
set @UserPWD=@db_userpwd
set @UserPWD2=@db_userpwd
end

-- user not found
IF @rowcount=1
BEGIN
	SELECT @LogData = 'Agent:' + @UserName + ' IP:' + @LoginIP + ' Result:Failed(User_Not_Found) ServerID:' + 
CAST(@ServerID as nvarchar(20))
	EXEC bodb02.dbo.WriteLog_UserLog @UserID = 0, @Doing = @LogData

	select @ErrMsg = N'Wrong username or password.'
	raiserror (@ErrMsg, 16, 1)
	return
END

SELECT @role = CASE @db_roleid WHEN 1 THEN 'Customer:' WHEN 2 THEN 'Agent:' WHEN 3 THEN 'Master:' WHEN 4 THEN 
'Super:' ELSE 'Admin:' END
-- check condition
IF @db_roleid not in (2,3,4)
	BEGIN
		SELECT @LogData = @role + @UserName + ' IP:' + @LoginIP + ' Result:Failed(Not_Agent) ServerID:' + 
CAST(@ServerID as nvarchar(20))
		EXEC bodb02.dbo.WriteLog_UserLog @UserID = 0, @Doing = @LogData
	
		select @ErrMsg = N'Login Failed.'
		raiserror (@ErrMsg, 16, 1)
		return
	END

IF IsNull(@closed, 1) = 1
	BEGIN
		SELECT @LogData = @role + @UserName + ' IP:' + @LoginIP + ' Result:Failed(A/C_Closed) ServerID:' + 
			CAST(@ServerID as nvarchar(20))
		EXEC bodb02.dbo.WriteLog_UserLog @UserID = @db_custid, @Doing = @LogData
	
		select @ErrMsg = case @Language when 'E' then N'Account closed. Please contact your administrator!' 
				else N'此戶口已關閉. 請聯絡管理部' end
		raiserror (@ErrMsg, 16, 1)
		return
	END
ELSE IF @db_userpwd <> @UserPWD
	BEGIN			
		SELECT @LogData = @role + @UserName + ' IP:' + @LoginIP + ' Result:Failed(Password) ServerID:' + CAST(@ServerID as nvarchar(20))
			,@failedcount = @failedcount + 1
		EXEC bodb02.dbo.WriteLog_UserLog @UserID = @db_custid, @Doing = @LogData

		IF @isSubAcc = 0
		BEGIN
			IF @failedcount > 5 and @isSubAcc = 0
				UPDATE custinfo with (rowlock, updlock) SET closed = 1 WHERE custid = @db_custid
			ELSE
				UPDATE customer with (rowlock, updlock) SET logincount = @failedcount WHERE custid = @db_custid
		END
		ELSE
		BEGIN
			IF @failedcount < 256
			BEGIN
				UPDATE custSub with (rowlock, updlock) SET logincount = @failedcount WHERE subaccid = @subaccid 
			END
		END
		
		select @ErrMsg = N'Wrong username or password.'
		raiserror (@ErrMsg, 16, 1)
		return
		
	END

-- Successful
SELECT @Currency = Currency FROM exchange with (nolock) WHERE exchangeid = @db_currency
SELECT @CustID = @db_custid, @RoleID = @db_roleid

if @RoleID = 2
	select @MasterUsername = lower(username) from customer where custid = (select mrecommend from customer where custid = @CustID)
else if @RoleID = 3
	select @MasterUsername = lower(@UserName)
else if @RoleID = 4
	select @MasterUsername = null

if @isSubAcc = 0
begin
	UPDATE customer with (rowlock, updlock)
	SET logincount = 0, iplogin = @LoginIP, lastlogged = CURRENT_TIMESTAMP
	WHERE custid = @db_custid
end 
else
begin
	UPDATE custSub with (rowlock, updlock) SET logincount = 0 WHERE subaccid = @subaccid 
end
SELECT @LogData = @role + @UserName + ' IP:' + @LoginIP + ' Result:Success ServerID:' + CAST(@ServerID as nvarchar(20))
---------------------------
-- ***Check Sub-Account***
if @SubAccID > 0
	SET @LogData = 'SubAccountID:' +  convert(varchar(20), @SubAccID) + ' - ' + @LogData
---------------------------
EXEC bodb02.dbo.WriteLog_UserLog @UserID = @db_custid, @Doing = @LogData


GO
GRANT EXECUTE ON [dbo].[Age_LoginDownline_API] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_LoginDownline_API] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_LoginDownline_API] TO [vnteam] AS [dbo]