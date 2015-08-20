ALTER PROCEDURE [dbo].[All_BetList_MatchResultDetail3rdSel]
	@BetId BIGINT 
AS

/*
	Created: 20150622@Sophia
	Task: Get Result from Betlist for Metric Gaming
	DB: DBAGE/bodb02; DBEXT/bodb02 

	Original:   
		-20150622@Sophia : Initial - Get Result from Betlist for Mertric Gaming [#36469]
		-20150819@Sophia: Harcode OtherInfo = '' when gameId = 806
	Revisions: 	 
   			
	Param's Explanation: 
		@BetId : BetId of Bettrans Table

*/

BEGIN 
	SET NOCOUNT ON 

	IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail3rd R WITH (NOLOCK) WHERE R.ResultID = @BetId )
	BEGIN 
		SELECT	R.ResultID
				,R.VendorID
				,R.MatchID
				,R.GameID
				,R.Custom1
				,R.Custom2
				,R.Custom3
				,R.ResultStatusID
				,R.SettlementStatusID
				,R.GameResult
				,CASE WHEN R.GameID = 806 THEN '' ELSE R.OtherInfo END AS OtherInfo
				,M.homeid
				,M.awayid
				,M.Leagueid
		FROM	dbo.ResultDetail3rd R WITH (NOLOCK)
		INNER JOIN dbo.Match M WITH (NOLOCK) 
			ON	M.MatchId = R.MatchId
		WHERE R.ResultID = @BetId
	END 
	ELSE
	IF EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail3rd14 R WITH (NOLOCK) WHERE R.ResultID = @BetId )
	BEGIN 
		SELECT	R.ResultID
				,R.VendorID
				,R.MatchID
				,R.GameID
				,R.Custom1
				,R.Custom2
				,R.Custom3
				,R.ResultStatusID
				,R.SettlementStatusID
				,R.GameResult
				,CASE WHEN R.GameID = 806 THEN '' ELSE R.OtherInfo END AS OtherInfo
				,M.homeid
				,M.awayid
				,M.Leagueid
		FROM	dbo.ResultDetail3rd14 R WITH (NOLOCK)
		INNER JOIN dbo.Match14 M WITH (NOLOCK) 
			ON	M.MatchId = R.MatchId
		WHERE R.ResultID = @BetId
	END
	ELSE
	IF EXISTS (SELECT TOP 1 1 FROM DBARC.bodb_archive.dbo.ResultDetail3rd_bk R WITH (NOLOCK) WHERE R.ResultID = @BetId )
	BEGIN
		SELECT	R.ResultID
				,R.VendorID
				,R.MatchID
				,R.GameID
				,R.Custom1
				,R.Custom2
				,R.Custom3
				,R.ResultStatusID
				,R.SettlementStatusID
				,R.GameResult
				,CASE WHEN R.GameID = 806 THEN '' ELSE R.OtherInfo END AS OtherInfo
				,M.homeid
				,M.awayid
				,M.Leagueid
		FROM	DBARC.bodb_archive.dbo.ResultDetail3rd_bk R WITH (NOLOCK)
		INNER JOIN DBARC.bodb_archive.dbo.Match_bk M WITH (NOLOCK) 
			ON	M.MatchId = R.MatchId
		WHERE R.ResultID = @BetId
	END

END

GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultDetail3rdSel] TO [bodbDownlineNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultDetail3rdSel] TO [bodbExtAccNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultDetail3rdSel] TO [bodbDownlineNetView]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultDetail3rdSel] TO [bodbAdminNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultDetail3rdSel] TO [bodbLicenseeNet]
GO


 
  