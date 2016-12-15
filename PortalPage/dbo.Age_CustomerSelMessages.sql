USE [bodb_Message]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_CustomerSelMessages]
	@targetID int = 0,
	@targetID2 varchar(100) = '0',
	@lastPostTime DateTime = '9999-12-31',---'9999-12-31',
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
		- 20140106@Viet: revise SP.
		- 20161130@Paul: return vietnamese content [RedmineID #66535]
*/
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @startdate DATETIME
	DECLARE @targetTable TABLE (TargetID INT)

	SET @startdate = DATEADD(month, - 1, CURRENT_TIMESTAMP)

	INSERT INTO @targetTable (TargetID)
	SELECT val
	FROM dbo.strSplit(@targetid2, ',')
	UNION ALL
	SELECT @TargetID
	
	SELECT DISTINCT TOP (@totalMessage) m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
			m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,	m.Content_es, m.Content_vn,
			m.PostTime, m.MsgType, m.IsSticky, m.LastUpdateTime, mt.bettransid, mt.isRead	
	FROM dbo.Msg m WITH(NOLOCK)
		INNER JOIN dbo.MsgTarget mt with (NOLOCK, INDEX=IX_TargetId) ON m.MessageId = mt.MessageId
		INNER JOIN @targetTable t ON mt.TargetID = t.TargetID
	WHERE m.PostTime BETWEEN @startdate AND @lastPostTime			
			AND m.isDeleted = 0
			AND m.MessageId > 522518
			AND COALESCE(NULLIF(@isTest,1),m.IsTest) = m.IsTest			
			AND mt.isDeleted = 0			
	ORDER BY m.Posttime	DESC

	/*
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
		
		declare @targetTable table (TargetID int)
		insert into @targetTable (TargetID)
		SELECT val from dbo.strSplit(@targetid2,',')
		UNION ALL SELECT @TargetID
		
		SELECT DISTINCT m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
				m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,	m.Content_es, m.PostTime, 
				m.MsgType, m.IsSticky, m.LastUpdateTime, mt.bettransid, mt.isRead	
		FROM dbo.Msg m with (NOLOCK)
			inner join MsgTarget mt with (NOLOCK) ON m.MessageId=mt.MessageId AND m.Posttime<@lastPostTime
			inner join @targetTable tt ON mt.TargetID = tt.TargetID
		WHERE	m.Posttime >= @startdate --20120114: fix by Sylvia 
				AND m.isTest = 0
				AND mt.isDeleted = 0
				AND m.isDeleted = 0
				AND m.MessageId > 396778 --20130809@vivi (372773), 20130928@Sylvia (376259)
		ORDER BY m.Posttime	DESC
	END

	SET ROWCOUNT 0

	*/
END










GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMessages] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelMessages] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelMessages] TO [vnteam]