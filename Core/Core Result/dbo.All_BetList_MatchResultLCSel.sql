CREATE PROCEDURE [dbo].[All_BetList_MatchResultLCSel]
	@TransId BIGINT 
AS
/*
Created: 20160203@Sophia
Task: Get Result from Betlist for AllBet [#50866]
DB: DBAGE/bodb02; DBEXT/bodb02 

Original:   
  
Revisions: 	 
   			
Param's Explanation: 
	@TransID: TransId of Bettrans table

*/

BEGIN 
	SET NOCOUNT ON 

		DECLARE @TransDesc NVARCHAR(1000), @GameId SMALLINT

		SELECT	@TransDesc = TransDesc, @GameId = GameId
		FROM	dbo.bettransLC WITH (NOLOCK)
		WHERE	TransId = @TransId
	
		IF @TransDesc IS NULL 
		BEGIN 
			SELECT	@TransDesc = TransDesc, @GameId = GameId
			FROM	dbo.bettransLC14 WITH (NOLOCK)
			WHERE	TransId = @TransId
		END
		
		IF @TransDesc IS NULL 
		BEGIN 
			SELECT	@TransDesc = TransDesc, @GameId = GameId
			FROM	DBARC.bodb_archive.dbo.bettransLC_BK WITH (NOLOCK)
			WHERE	TransId = @TransId
		END 

		SELECT @TransDesc as TransDesc , @GameId AS GameId

END 


GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultLCSel] TO [bodbDownlineNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultLCSel] TO [bodbExtAccNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultLCSel] TO [bodbDownlineNetView]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultLCSel] TO [bodbAdminNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultLCSel] TO [bodbLicenseeNet]
GO


 