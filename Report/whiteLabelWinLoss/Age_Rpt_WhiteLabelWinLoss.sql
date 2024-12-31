/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Rpt_WhiteLabelWinLoss]
	@CustID 		INT, --recommend/ mrecommend/ srecommend
	@UserName		VARCHAR(30) = '',
	@WhiteLabelList VARCHAR(MAX) = '',
	@FromDate 		SMALLDATETIME,
	@ToDate 		SMALLDATETIME
AS
/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label winloss report - [Redmine: #209633]
	-- super
		EXEC Age_Rpt_WhiteLabelWinLoss 
				@CustID 		= 4,
				@UserName		= 'M85TB01',
				@FromDate 		= '2024-07-01',
				@ToDate 		= '2024-07-31',
				@WhiteLabelList = '113125,133152,133234,5979,120809,31912,71345,64209,64207,114951'
	-- master
		EXEC Age_Rpt_WhiteLabelWinLoss 
			@CustID 		= 15517,
			@UserName		= '',
			@WhiteLabelList = '64209,64207',
			@FromDate 		= '2024-07-01',
			@ToDate 		= '2024-07-31'
	-- agent
		EXEC Age_Rpt_WhiteLabelWinLoss 
			@CustID 		= 64207,
			@UserName		= '',
			@FromDate 		= '2024-07-01',
			@ToDate 		= '2024-07-31'
*/

BEGIN
	SET NOCOUNT ON;
	DECLARE @FDate	SMALLDATETIME,
			@TDate	SMALLDATETIME

	SELECT	@FDate = @FromDate, @TDate = @ToDate

	DECLARE @RoleID TINYINT
	SELECT @RoleID = RoleID FROM dbo.CustInfo WITH(NOLOCK) WHERE CustID = @CustID

	DECLARE @UserName_CustId INT, @UserName_RoleID TINYINT

	IF @Username <> ''
	BEGIN
		SELECT @UserName_CustId = ISNULL(Custid, -1), @UserName_RoleID = RoleID
		FROM  dbo.Customer WITH (NOLOCK) WHERE username = @UserName
	END
	ELSE				
	BEGIN
		SET @UserName_CustId = 0
	END

	DROP TABLE IF EXISTS #WhiteLabelList
	CREATE TABLE #WhiteLabelList (custID INT, WhiteLabel NVARCHAR(50), LaunchedDate SMALLDATETIME)

	INSERT INTO #WhiteLabelList (custID, WhiteLabel, LaunchedDate)
	SELECT wl.custID, wl.WhiteLabel, wl.LaunchedDate
	FROM  WhiteLabelInfo wl WITH(NOLOCK)
	INNER JOIN CustInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid
	WHERE (wl.CustID IN (SELECT CAST(value AS INT) FROM STRING_SPLIT (@WhiteLabelList,',')) OR (wl.CustID = @CustID AND @RoleID =2 ) )
		AND (
			(@RoleID = 4 AND ci.srecommend = @CustID)
			OR (@RoleID = 3 AND ci.mrecommend = @CustID)
			OR (@RoleID = 2 AND ci.recommend = @CustID)
		)
		AND (
			(	
				(
				@UserName_CustId = 0 
				OR (  ci.MRecommend = @UserName_CustId AND  @UserName_RoleID = 3)
				OR (  ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
				) AND @RoleID = 4
			)
		OR (	
				(
				@UserName_CustId = 0 
				OR (  ci.Recommend = @UserName_CustId AND  @UserName_RoleID = 2)
				) AND @RoleID = 3
			)
		OR ( @RoleID = 2 	AND @UserName_CustId = 0 )
		)


	IF @RoleID = 2 -- Agent
	BEGIN
		SELECT	w.WinlostDate, 
				SUM( CASE WHEN TypeID = 0 THEN  WinLoss ELSE 0 END) AS MemberWinloss,
				SUM( CASE WHEN TypeID IN (2,3,4,5,6) THEN  WinLoss ELSE 0 END) AS Promotion
		FROM   bodb_WhiteLabel.dbo.WhiteLabelWinloss w WITH(NOLOCK)
		INNER JOIN #WhiteLabelList wlb ON w.CustID = wlb.custID
		WHERE  w.WinlostDate BETWEEN @FDate AND @TDate AND w.WinlostDate >= wlb.LaunchedDate
		GROUP BY w.WinlostDate
		ORDER BY  w.WinlostDate
	
	END
	
	IF @RoleID = 3 -- Master
	BEGIN
		SELECT	w.WinlostDate, 
				wlb.WhiteLabel WhiteLabelName,
				w.Recommend AS CustID, 
				c.username AS Agent, 
				SUM( CASE WHEN TypeID = 0 THEN  WinLoss ELSE 0 END) AS MemberWinloss,
				SUM( CASE WHEN TypeID IN (2,3,4,5,6) THEN  WinLoss ELSE 0 END) AS Promotion

		FROM   bodb_WhiteLabel.dbo.WhiteLabelWinloss w WITH(NOLOCK)
		INNER JOIN #WhiteLabelList wlb ON w.CustID = wlb.custID
		LEFT JOIN dbo.Customer c WITH(NOLOCK) ON w.Recommend = c.CustID
		WHERE  WinlostDate BETWEEN @FDate AND @TDate AND w.WinlostDate >= wlb.LaunchedDate
		GROUP BY w.WinlostDate, w.Recommend, c.username, wlb.WhiteLabel
		ORDER BY  w.WinlostDate,  c.username
	END

	IF @RoleID = 4 -- Super
	BEGIN
		SELECT	w.WinlostDate, 
				cm.username AS Master,   
				wlb.WhiteLabel WhiteLabelName,
				cr.username AS Agent,
				SUM( CASE WHEN TypeID = 0 THEN  WinLoss ELSE 0 END) AS MemberWinloss,
				SUM( CASE WHEN TypeID IN (2,3,4,5,6) THEN  WinLoss ELSE 0 END) AS Promotion
		FROM   bodb_WhiteLabel.dbo.WhiteLabelWinloss w WITH(NOLOCK)
		INNER JOIN #WhiteLabelList wlb ON w.CustID = wlb.custID
		LEFT JOIN dbo.Customer cm WITH(NOLOCK) ON w.MRecommend = cm.CustID
		LEFT JOIN dbo.Customer cr WITH(NOLOCK) ON w.Recommend = cr.CustID
		WHERE   WinlostDate BETWEEN @FDate AND @TDate  AND w.WinlostDate >= wlb.LaunchedDate
		GROUP BY w.WinlostDate, cm.username, cr.username, wlb.WhiteLabel
		ORDER BY  w.WinlostDate,  cm.username, cr.username
	END

	SET NOCOUNT OFF;
END
GO