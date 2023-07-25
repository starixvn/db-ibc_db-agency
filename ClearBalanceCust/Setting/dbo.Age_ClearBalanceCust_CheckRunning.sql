/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Age_ClearBalanceCust_CheckRunning
	@CustID			INT
	,@Language		VARCHAR(2)= 'E'
	,@ErrCode		INT = 0 OUTPUT 
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created:20230227@Bobby
	Task: 182071 - Auto Transfer/ Multiple Transfer	
	DB: DBSIC-bodb02,DBCTG-bodb02

	Revisions:
		- 20230227@Bobby: AutoJob clear balance downlines [RedmineID: #182071]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Recommend INT, @MRecommend INT, @SRecommend INT
	SELECT @ErrMsg = '', @ErrCode = 0 

	SELECT 	@CustID = CustID, @Recommend = Recommend, @MRecommend = MRecommend, @SRecommend = SRecommend
	FROM 	CUSTDB.dbo.customer c WITH(NOLOCK)
	WHERE 	CustID = @CustID
	
	IF EXISTS (
				SELECT 	TOP 1 1  
				FROM 	bodb02.dbo.Age_ClearBalanceCust_Process s WITH(NOLOCK)
				WHERE 	--- check SMA is processing or not
					s.FromCustID IN (@CustID, @Recommend, @MRecommend, @SRecommend)
					AND s.[Status] IN ('Waiting', 'Processing', 'Pending')
		)
	BEGIN
		SELECT @ErrCode = 50020
		SELECT @ErrMsg = CustDB.dbo.f_Get_MsgNamebyMsgID (50020,@Language)
		 
	END

END
GO
