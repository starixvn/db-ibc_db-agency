/*<info serverAlias="DB054-bodb_APILog" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE API_WriteLog_UserLog_APILog_RunSP
    @username		NVARCHAR(50),
    @loginIP		VARCHAR(50)		= NULL,
    @browserName	VARCHAR(200)	= NULL,
    @platform		VARCHAR(200)	= NULL,
    @countryCode	VARCHAR(10)		= NULL,
    @actionName		VARCHAR(50)		= NULL,
    @requesTime		DATETIME		= NULL
AS
/*
	Created: 20191114
	Task: Insert log action for Alpha API
	DB: DB054/bodb_APILog

	Revisions:    
		- 20191114@Kan: Initial SP [Redmine:#]

	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON

    INSERT INTO dbo.UserLog_APILog
        (
        UserName,
        LoginIP,
        BrowserName,
        [Platform],
        CountryCode,
        ActionName,
        RequesTime,
        LogDate
        )
    VALUES
        (
            @username,
            @loginIP,
            @browserName,
            @platform,
            @countryCode,
            @actionName,
            @requesTime,
            GETDATE()
        )
END	
GO
