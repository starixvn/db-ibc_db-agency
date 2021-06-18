/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested=""></info>*/

ALTER PROCEDURE [dbo].[Age_CustomerSelMessages]
	@targetID int = 0,
	@targetID2 varchar(100) = '0',
	@lastPostTime DateTime = '9999-12-31',---'9999-12-31',
	@totalMessage int = 10,
	@isTest bit = 0
/*
	Created: Johnson
	Date: 2011-05-23
	DB: DBMSG/bodb_Message	
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
		- 20170428@Percy: sort by top level message [RedmineID: #75763]
		- 20190719@Andy: return content_zhcn to support for cn88 new simplify Chinese [RedmineID: #117259]
		- 20210618@Patrick: Revise SP
*/
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @startdate DATETIME
	CREATE TABLE #targetTable (TargetID INT)

	SET @startdate = DATEADD(month, - 1, CURRENT_TIMESTAMP)

	INSERT INTO #targetTable (TargetID)
	SELECT val
	FROM dbo.strSplit(@targetid2, ',')
	UNION ALL
	SELECT @TargetID

	CREATE TABLE #Msg (MessageId INT, targetId int)
	INSERT INTO #Msg (MessageId, targetId)
	SELECT TOP (@totalMessage) m.MessageId, t.TargetID
	FROM dbo.Msg m WITH(NOLOCK)
		INNER JOIN dbo.MsgTarget mt with (NOLOCK) ON m.MessageId = mt.MessageId
		INNER JOIN #targetTable t ON mt.TargetID = t.TargetID
	WHERE m.PostTime BETWEEN @startdate AND @lastPostTime			
			AND m.isDeleted = 0
			AND m.MessageId > 522518
			AND COALESCE(NULLIF(@isTest,1),m.IsTest) = m.IsTest			
			AND mt.isDeleted = 0
	ORDER BY m.TopLevel ASC, m.Posttime	DESC

	SELECT DISTINCT TOP (@totalMessage) m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
			m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,	m.Content_es, m.Content_vn, m.Content_zhcn,
			m.PostTime, m.MsgType, m.IsSticky, m.LastUpdateTime, mt.bettransid, mt.isRead, m.TopLevel
	FROM #Msg tmp
		INNER JOIN dbo.MsgTarget mt with (NOLOCK) ON tmp.MessageId = mt.MessageId and tmp.targetId = mt.TargetId
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
	ORDER BY m.TopLevel ASC, m.Posttime	DESC

	DROP TABLE #targetTable
	DROP TABLE #Msg
END