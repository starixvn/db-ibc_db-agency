
ALTER PROCEDURE [dbo].[Age_CustomerSelMessages]
	@targetID int = 0,
	@targetID2 varchar(100) = '0',
	@lastPostTime DateTime = '9999-12-31',
	@totalMessage int = 10,
	@isTest bit = 0
/*
	Created: Johnson
	Date: 2011-05-23
	DB: DB07.bodb_Message	
	Task: get announcement for super in Portal Page
	
	Revisions:
		- 20111115@Viet: Revise SP
		- 20111212@Jamie: Optimize code for filtering 
		- 20120111@Jamie: Get top 50 instead of 20 
		- 20120112@Lukas: Exclude messages with isDeleted = 1
		- 20120116@Vivi: only query one month ago message
		- 20120418@Leo: query records with 2 additional params
*/
AS

SET NOCOUNT ON;

declare @startdate datetime
select @startdate = DATEADD(month,-1,CURRENT_TIMESTAMP)

SET ROWCOUNT @totalMessage 

IF @isTest=1 
BEGIN
	SELECT DISTINCT m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
			m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,	m.Content_es, 
			m.PostTime, m.MsgType, m.IsSticky, m.LastUpdateTime, mt.bettransid, mt.isRead	
	FROM dbo.Msg m with (NOLOCK)
		inner join MsgTarget mt with (NOLOCK) ON m.MessageId=mt.MessageId AND m.Posttime<@lastPostTime
	WHERE m.Posttime >= @startdate --20120114: fix by Sylvia 
		AND mt.TargetID IN (
				SELECT val from dbo.strSplit(@targetid2,',')
				UNION ALL SELECT @TargetID
			)
		AND mt.isDeleted = 0 
		AND m.isDeleted = 0
	ORDER BY m.Posttime	DESC
END
ELSE
BEGIN
	SELECT DISTINCT m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
			m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,	m.Content_es, m.PostTime, 
			m.MsgType, m.IsSticky, m.LastUpdateTime, mt.bettransid, mt.isRead	
	FROM dbo.Msg m with (NOLOCK)
		inner join MsgTarget mt with (NOLOCK) ON m.MessageId=mt.MessageId AND m.Posttime<@lastPostTime
	WHERE	m.Posttime >= @startdate --20120114: fix by Sylvia 
			AND mt.TargetID IN (
				SELECT val from dbo.strSplit(@targetid2,',')
				UNION ALL SELECT @TargetID
			)
			AND m.isTest = 0
			AND mt.isDeleted = 0
			AND m.isDeleted = 0
	ORDER BY m.Posttime	DESC
END

SET ROWCOUNT 0



GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMessages] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMessages] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelMessages] TO [RDScott]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelMessages] TO [vnteam]