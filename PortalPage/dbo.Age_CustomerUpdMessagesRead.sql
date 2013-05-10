 
 ALTER PROCEDURE [dbo].[Age_CustomerUpdMessagesRead]
	@userID int = 0,
	@messageIDs VARCHAR(4000) = ''
	
/*
	Created: Johnson
	Date: 2011-07-19
	DB: DB07.bodb_Message	
	Task: Update personal message to is read

	Revisions:
		- 20111028@Johnson: Fix bugs Split message
		- 20120112@Lukas: Exclude messages with isDeleted = 1
		- 20120208@Jamie: Add log into MsgLog table 
*/
AS

SET NOCOUNT ON

DECLARE @tmpMsg TABLE(messageID INT)

INSERT INTO @tmpMsg
SELECT val
FROM strSplit(@messageIDs,',')


UPDATE MsgTarget WITH(UPDLOCK,ROWLOCK)
SET isRead = 1 
WHERE targetID = @userID 
	AND messageID IN (SELECT messageID FROM @tmpMsg)
	AND isDeleted = 0

-- Write Log 
INSERT INTO [bodb_Message].[dbo].[MsgLog]
		   ([Site]
		   ,[OpratorID]
		   ,[MessageId]
		   ,[LogContent]
		   ,[ActionType]
		   ,[Method]
		   ,[LogDate])	
SELECT	DISTINCT	
			1, -- Agent Site
			@UserID,
			messageID,
			'Public Message',
			'E',
			'Age_CustomerUpdMessagesRead',
			GETDATE()	
	FROM	@tmpMsg

GO
GRANT EXECUTE ON [dbo].[Age_CustomerUpdMessagesRead] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerUpdMessagesRead] TO [vnteam]