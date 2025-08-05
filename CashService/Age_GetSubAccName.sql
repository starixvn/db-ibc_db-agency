/*<info serverAlias="DBSIC-bodb02" executers="asv_CashService,wsv_CashService,wsv_nap,wsv_alp,wsv_alpv,wsv_xnap" selecters="" viewers="" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE Age_GetSubAccName
	@SubAccID INT = 0,
	@SubAccName	VARCHAR(30) = NULL OUTPUT
AS 
/*
	Created: 20250729@Eden		
	Task: get Sub account username
	DB:  DBSIC-bodb02
		
	Revisions:
		- 20250729@Eden: Alpha - Agency Cash Service - Sprint 7 [redmine: #233481] 

	Parameter's Explanation:	
	Sample:
		DECLARE @SubAccID INT,
				@SubAccName	VARCHAR(30)
		EXEC Age_GetSubAccName 
			 @SubAccID = 1997747
			,@SubAccName = @SubAccName OUTPUT

		SELECT @SubAccName AS SubAccName 
*/ 
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@SubAccID,0) > 0 
	BEGIN	
		SELECT @SubAccName = username 
		FROM DBCUST.CustDB.dbo.custSub WITH(NOLOCK) 
		WHERE SubAccID = @SubAccID
	END
	ELSE 
	BEGIN
		SET @SubAccName = ''
	END
END
GO