USE [bodb_CustomerLog]
GO
/****** Object:  StoredProcedure [dbo].[Acc_UserLog_LoginSel]    Script Date: 10/19/2010 12:09:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Acc_UserLog_LoginSel]
    @UserId INT,
	@UserName AS VARCHAR(50),
    @FromDate DATETIME,
    @ToDate DATETIME,    
    @IsAdminAccess BIT = 0,
    @PageIndex INT,
    @PageSize INT
AS 
/* Created:20100121@Lewin
    Task: ViewLog function 331
    DB: bodb_CustomerLog

	Description:
	- Get paged log credit
	Revisions:
	- 20100710@Kiwi: put in a check to return retrieving data if roleid = 1
	- 20100711@Thien: add index hint
	- 20101018@Anders: query columns Browser, Domain, Planform, CountryCode
	
	
    Param's Explaination:    
	- @UserId: a customer which we want to view actions affect to.
	- @UserName: customer name type in textbox to search
	- @FromDate: date range to view log
	- @ToDate: date range to view log
	- @IsAdminAccess: Accouting site TRUE, agent = FALSE
	- @PageIndex: from 0
	- @PageSize: total record per request
*/

SET NOCOUNT ON ;
--		BEGIN CALCULATE BEGIN RECORD INDEX AND END RECORD INDEX    
SET @PageIndex = ABS(@PageIndex)
SET @PageSize = ABS(@PageSize)          

DECLARE @lbound INT 
DECLARE @ubound INT

SET @lbound = @PageIndex * @PageSize       
	
SET @ubound = @lbound + @PageSize 
IF ( @PageIndex > 0 ) 
    SET @lbound = @lbound + 1
--		END CALCULATE BEGIN RECORD INDEX AND END RECORD INDEX

--		PAGING QUERY

--RETURN TO RETRIEVE DATA IF ROLEID = 1 
DECLARE @RoleID tinyint
SELECT @RoleID = roleid from bodb02.dbo.custinfo(nolock) where custid = @UserId
IF (@RoleID = 1)
	RETURN
print @RoleID 

IF (@IsAdminAccess = 0)
BEGIN
	SELECT  LogID,
			UserID,
			Username,
			Doing,
			LogDate,
			ActionID,				
			IsInternal,				
			ActionName,
			SPName,
			IP,
			ServerID,
			Browser,
			Domain,
			[Platform],
			CountryCode
	FROM    (
				 SELECT    ROW_NUMBER() OVER (ORDER BY  LogDate DESC) AS RowNum,
							LogID,
							UserID,
							@UserName AS Username,
							Doing,
							LogDate,
							la.ActionID,				
							IsInternal,							
							la.ActionNameEN AS ActionName,
							la.SPName AS SPName,
							IP,
							ServerID, 
							BrowserName as Browser,
							DomainName as Domain,
							[Platform],
							CountryCode
				  FROM      dbo.UserLog_Login AS ul WITH(NOLOCK, index=CIX_LogDate_User)
							INNER JOIN dbo.LogAction AS la WITH(NOLOCK) ON ul.ActionID = la.ActionID
				  WHERE     LogDate BETWEEN @FromDate AND @ToDate			
							AND IsInternal <= @IsAdminAccess
							AND ((	UserID = @UserId AND SubAccID = 0)
									OR (SubAccID = @UserId))
			) AS MyTable
	WHERE   RowNum BETWEEN @lbound AND @ubound
END
ELSE
BEGIN
	SELECT  LogID,
			UserID,
			Username,
			Doing,
			LogDate,
			ActionID,				
			IsInternal,
			ActionName,
			SPName,
			IP,
			ServerID,
			Browser,
			Domain,
			[Platform],
			CountryCode
	FROM    (
				 SELECT    ROW_NUMBER() OVER ( ORDER BY LogDate DESC) AS RowNum,
							LogID,
							UserID,
							@UserName AS Username,
							Doing,
							LogDate,
							la.ActionID,				
							IsInternal,										
							la.ActionNameEN AS ActionName,
							la.SPName AS SPName,
							IP,
							ServerID,BrowserName as Browser,
							DomainName as Domain,
							[Platform],
							CountryCode
				  FROM      dbo.UserLog_Login AS ul WITH(NOLOCK, index=CIX_LogDate_User)
							INNER JOIN dbo.LogAction AS la WITH(NOLOCK) ON ul.ActionID = la.ActionID
				  WHERE     LogDate BETWEEN @FromDate AND @ToDate			
							AND IsInternal <= @IsAdminAccess
							AND ((	UserID = @UserId AND SubAccID <= 0)
									OR (SubAccID = @UserId))
			) AS MyTable
	WHERE   RowNum BETWEEN @lbound AND @ubound
END


