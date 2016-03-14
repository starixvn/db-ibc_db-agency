USE [bodb02]
GO
/****** Object:  UserDefinedFunction [dbo].[f_SportBettypeMatrix_Sel_Mode4]    Script Date: 03/10/2016 05:24:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  User Defined Function dbo.f_SportBettypeMatrix_Sel_Mode4    Script Date: 3/9/2016 10:34:24 ******/

ALTER FUNCTION [dbo].[f_SportBettypeMatrix_Sel_Mode4]
(
	@ProductID		TINYINT		 = 0
	,@SportType		SMALLINT	 = 0
	,@BetType		SMALLINT	 = 0
	,@IsLive		TINYINT		 = 2
	,@SubProduct	VARCHAR(500) = ''
	,@ProductPrefix VARCHAR(500) = ''
	,@IsTest		BIT
) 
/*
		Created: Francis	
		DateCreated: 20160307
		Task: Get SportType_Bettype
		DB: DBAGE.BODB02
		
		Revisions:
		
		Paramters Explanation:
			@Mode: 
				0: Product ( ProductID,ProductName,ProductPrefix)
				1: SportType (ProductID,SportType)
				2: BetType (ProductID,SportType,BetType,EventType)
					- Get all : Live and Non-live
				3: BetType (ProductID,SportType,BetType,IsLive,EventType)
					- Get	: Live or Non-live
				4: BetType (ProductID,BetType,EventType)
					- Get all : Live or Non-live
				5: BetType (ProductID,BetType,EventType,SubProduct)
					- Get all : Live or Non-live
 			@ProductID,@SportType,@BetType
				0	: get all
				<>0 : check condition
			@IsLive : check paramer which @mode > 0
				0	: None-live
				1	: Live
				2	: None-live & Live
			@ProductPrefix:
				''  : get all
				<>'': Check ProductPrefix column on dbo.Product table
			@IsTest:
				1: Get all products and bettypes
				0: Get only products and bettypes which are not being tested
*/

RETURNS TABLE
RETURN
SELECT DISTINCT
	ma.ProductID
	,ma.BetType
	,ma.EventType
	,ma.SubProduct
FROM dbo.SportBettypeMatrix ma WITH(NOLOCK)
	INNER JOIN dbo.Products p WITH(NOLOCK)
		ON p.ProductID = ma.ProductID
WHERE  (@ProductID = 0 OR ma.ProductID = @ProductID)
	AND (@SportType = 0 OR  ma.SportType = @SportType)
	AND (@BetType = 0 OR  ma.BetType = @BetType)			
	AND (@IsLive = 2 OR  ma.IsLive = @IsLive)
	AND (@SubProduct = '' OR  ma.SubProduct = @SubProduct)
	AND
		(ma.IsTest = 0
		OR ma.IsTest = @IsTest
		)
	AND (@ProductPrefix = '' OR p.ProductPrefix IN (SELECT val FROM strSplit(@ProductPrefix, ',')))
GO
GRANT VIEW DEFINITION ON [dbo].[f_SportBettypeMatrix_Sel_Mode4] TO [vnteam] AS [dbo]