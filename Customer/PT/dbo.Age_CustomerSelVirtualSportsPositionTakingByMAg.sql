 ALTER PROCEDURE [dbo].[Age_CustomerSelVirtualSportsPositionTakingByMAg]
(
	@MRecommend INT,
	@PageIndex	INT = 1,
	@PageSize	INT = 10000,
	@TotalPages	INT = 0 OUTPUT
)
AS
/*

	Created: 20120809@Sophia
	Date:  
	Task : Select Virtual Sports for PT List from custsettinggame
	DB: DBAGE/bodb02
	Original: Age_CustomerSelPositionTakingByMAg

	Revisions: 
		- 20121204@Tom: Add  virtual tennis setting (sporttype : 186 , bettype : 1220)
		- 20130305@Johnson: add virtual horse racing setting (sporttype: 181)
	Param's Explanation:
	• @MRecommend: Master Agent ID
*/
BEGIN

	SET NOCOUNT ON

	SELECT 
		@TotalPages = COUNT(ci.custid),@TotalPages=@TotalPages/@PageSize + CASE WHEN @TotalPages%@PageSize > 0 THEN 1 ELSE 0 END
	FROM 
		custinfo AS ci WITH (NOLOCK)		
	WHERE 
		ci.MRecommend = @MRecommend AND ci.roleid=2 


	SELECT * 
	FROM 
	(
		SELECT 
			ROW_NUMBER() OVER( ORDER BY CASE WHEN ISNULL(ci.enabled,0) = 0 THEN 3 
											WHEN ISNULL(ci.closed,0) = 1 THEN 2 
											WHEN ISNULL(ci.reject,0) = 1 THEN 1 
											ELSE 0 
											END, ci.username) AS RowNumber,
			ci.closed, ci.enabled, 
			ci.DisableVirtualSports, ci.HideVirtualSports,
			ISNULL(ci.reject,0) AS suspended,
			ci.username, 
			ci.custid,

			MAX(CASE WHEN cg.sporttype=180 THEN cg.mpositiontaking ELSE 0 END) v180mpositiontaking,
			MAX(CASE WHEN cg.sporttype=180 THEN cg.apositiontaking ELSE 0 END) v180apositiontaking,
			
			MAX(CASE WHEN cg.sporttype=181 THEN cg.mpositiontaking ELSE 0 END) v181mpositiontaking,
			MAX(CASE WHEN cg.sporttype=181 THEN cg.apositiontaking ELSE 0 END) v181apositiontaking,
			
			MAX(CASE WHEN cg.sporttype=186 THEN cg.mpositiontaking ELSE 0 END) v186mpositiontaking,
			MAX(CASE WHEN cg.sporttype=186 THEN cg.apositiontaking ELSE 0 END) v186apositiontaking			
		FROM																									   
			custinfo AS ci WITH (NOLOCK)
			INNER JOIN CustSetting3rd AS cg WITH (NOLOCK) ON ci.custid = cg.custid	
		WHERE ci.MRecommend = @MRecommend AND ci.roleid=2 AND cg.sporttype in (180, 181, 186)
		GROUP BY
			ci.enabled, ci.closed, ci.DisableVirtualSports, ci.HideVirtualSports, ci.reject, ci.username, ci.custid	
	) t 
	WHERE RowNumber >= (@PageIndex-1)*@PageSize + 1 AND RowNumber <= @PageIndex*@PageSize
END





GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelVirtualSportsPositionTakingByMAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CustomerSelVirtualSportsPositionTakingByMAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerSelVirtualSportsPositionTakingByMAg] TO [VNTeam]
GO  