/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_ScoreMap_SelBettype]
AS

/*
	Task: Get bet types for Score Map function  
	Date: 20110919@Johnson  
	DB: DBAGE.bodb02   
	
	Revisions:  
		- 20120626@Sophia: Add new bettype 121, 122, 123 for Home no bet, Away no bet, Draw/No Draw
		- 20140417@Dom: Add new bettype 126
		- 20140807@Dom: Include 11 new bettypes of Soccer [feature: #19632]
		- 20150410@Tom: Modify Forecast function to support new 60 bet types [Feature #32738]
		- 20150828@Winnie: Myanmar odds
		- 20151126@Percy: Add Correct Score into the Live Ball Section [RedmineID: #48050]
		- 20160509@Percy: Add 2 bettype Correct Score (AOS) [RedmineID: #48785]
		- 20160722@Percy: Support parent-child bettype [RedmineID: #53152]
		- 20171020@Percy: Apply core function [RedmineID: #84913]

	Parameter's Explanations:
		EvenType: 0 DeadBall 1 LiveBall
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT
		CAST(TypeId AS SMALLINT)			AS typeid,
		CAST(isLive AS SMALLINT)			AS EvenType,
		CAST (bettypes AS VARCHAR(100))		AS [1stId],
		CAST (infoBettypes AS VARCHAR(100)) AS [InfoId]
	FROM dbo.f_GetBettypeScoreMap()
	ORDER BY OrderID, EvenType
END	
GO