USE [bodb_Message]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Eddie Chen
-- Create date: <Create Date,,>
-- Description:	To temporary solve ref private message high loading to web server
-- =============================================
ALTER PROCEDURE [dbo].[Dot_Msg_GetTopPriMessage24]
	@UserID int,
	@IsTest bit = 0,
	@LatestMsgID int = 0 -- Check new msg count that newer than this messageid
AS
BEGIN
    /*
    Created: @TWTeam
    Task: 
    DB: DB07
    Original:
    Revisions:
        
    Param's Explanation:
    */
	SET NOCOUNT ON;

	IF @IsTest=0
	
BEGIN
	--IF EXISTS (SELECT 1 FROM MsgTarget with (nolock) where targetid=@UserID)
	SELECT Top 1 m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
				 m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,m.IsTest,
				 m.Content_es, m.PostTime, m.CreateTime, m.LastUpdateTime, m.MsgType, m.IsSticky,
				 m.Creator, m.CreatorName,  m.LastUpdator, m.LastUpdateName,
				 mt.TargetId, mt.TargetName as UserName,
				 bm.Batchid,bm.BContent_en,bm.BContent_cs,bm.BContent_ch,bm.BContent_jp,bm.BContent_th,
				 bm.BContent_it,bm.BContent_ko,bm.BContent_es,
				 m.BettransID
	FROM dbo.Msg m with (nolock)
	INNER JOIN  dbo.MsgTarget  mt with (Nolock) ON m.MessageId = mt.MessageId 
	LEFT JOIN BatchMsg bm with (nolock) on m.batchid=bm.batchid
	WHERE m.posttime > dateadd(d,-1,getdate()) and m.MsgType=1 and mt.TargetId=@UserID
	AND m.MessageId > @LatestMsgID
	AND m.IsSticky = 0
	AND m.IsTest=0
	ORDER BY m.PostTime DESC
END
ELSE
BEGIN
	SELECT Top 1 m.MessageId, m.Content_en, m.Content_cs, m.Content_ch,
				 m.Content_jp, m.Content_th, m.Content_it, m.Content_ko,m.IsTest,
				 m.Content_es, m.PostTime, m.CreateTime, m.LastUpdateTime, m.MsgType, m.IsSticky,
				 m.Creator, m.CreatorName,  m.LastUpdator, m.LastUpdateName,
				 mt.TargetId, mt.TargetName as UserName,
				 bm.Batchid,bm.BContent_en,bm.BContent_cs,bm.BContent_ch,bm.BContent_jp,bm.BContent_th,
				 bm.BContent_it,bm.BContent_ko,bm.BContent_es,
				 m.BettransID
	FROM dbo.Msg m with (nolock)
	INNER JOIN dbo.MsgTarget mt with (nolock) ON m.MessageId = mt.MessageId 
	LEFT JOIN BatchMsg bm with (nolock) on m.batchid=bm.batchid
	WHERE m.posttime > dateadd(d,-1,getdate()) and m.MsgType=1 and mt.TargetId=@UserID
	AND m.MessageId > @LatestMsgID
	AND m.IsSticky = 0
	--AND m.IsTest = 1
	ORDER BY m.PostTime DESC
END
END

GO
GRANT EXECUTE ON [dbo].[Dot_Msg_GetTopPriMessage24] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Dot_Msg_GetTopPriMessage24] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Msg_GetTopPriMessage24] TO vnteam