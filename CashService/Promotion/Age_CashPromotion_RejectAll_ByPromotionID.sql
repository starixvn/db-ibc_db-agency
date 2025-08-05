/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE dbo.Age_CashPromotion_RejectAll_ByPromotionID
(
    @AgentID INT,
	@PromotionID INT,
	@SubAccID INT = 0,
    @IP VARCHAR(50) = '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg	VARCHAR(2000) = NULL OUTPUT,
	@ErrExtraInfo	VARCHAR(MAX) OUTPUT
)
AS
/*
	Created: 20250729@Eden		
	Task: Reject All Pending Promotion before deleted Promotion
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250723@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:	
		@StatusId: 
			3: Expired
			5: Rejected

		@TransIds:
			[
				{"CustID":1176092,"TransID":414256454774554624},
				{"CustID":1176097,"TransID":414256454774554625}
			]

	DECLARE @ErrCode INT,
			@ErrMsg VARCHAR(2000),
			@ErrExtraInfo VARCHAR(MAX)
	EXEC Age_CashPromotion_RejectAll_ByPromotionID  
		 @AgentID = 1176086
		,@PromotionID = 9050
		,@SubAccID = 1997747
		,@IP = '1.1.1.1'
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT
		,@ErrExtraInfo = @ErrExtraInfo OUTPUT
	SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg, @ErrExtraInfo AS ErrExtraInfo

*/ 
BEGIN
    SET NOCOUNT ON;
	DECLARE @Trans_Tbl TABLE (
        CustID INT ,
        TransID BIGINT
	)
	DECLARE @TransIds VARCHAR(MAX)

	CREATE TABLE #CashMember (CustId INT PRIMARY KEY)
	INSERT INTO #CashMember (CustId)
	SELECT c.CustId
	FROM CustDB.dbo.custInfo c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_CustInfoExtra vw ON vw.CustID = c.custid AND vw.ServiceType = 1
	WHERE c.recommend = @AgentID
		AND c.roleid = 1

	INSERT INTO @Trans_Tbl(CustID,TransID)
	SELECT c.CustId, c.TransId
	FROM dbo.CashTransaction c WITH (NOLOCK)
		INNER JOIN #CashMember ci ON ci.CustId = c.CustId
		INNER JOIN AgencyCashService.dbo.CashPromotion p WITH (NOLOCK) 
			ON p.PromotionID = JSON_VALUE(c.ExtraInfo, '$.PromotionID') 
				AND p.SiteDBGroupID = c.SiteDBGroupID
				AND p.IsSoftDeleted = 0
	WHERE c.StatusId = 2
		AND c.TransactionTypeID = 11 --Promotion
		AND JSON_VALUE(c.ExtraInfo, '$.PromotionID')  = @PromotionID

	IF EXISTS (SELECT 1 FROM @Trans_Tbl)
	BEGIN
		SELECT @TransIds =
		(
			SELECT CustID,TransID 
			FROM @Trans_Tbl
			FOR Json PATH
		)

		--Reject all pending promotion
		EXEC Age_CashPromotion_Reject_Multiple  
			 @TransIds = @TransIds
			,@AgentID = @AgentID
			,@SubAccID = @SubAccID
			,@StatusId = 5
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@ErrExtraInfo = @ErrExtraInfo OUTPUT
	END
    SET NOCOUNT OFF;
END;