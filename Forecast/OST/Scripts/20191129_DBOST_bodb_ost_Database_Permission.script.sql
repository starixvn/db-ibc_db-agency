/*
Created: 20191129@Bobby
DB: DBOST.bodb_ost
Task: Deploy UAT - New Alpha forecast [Redmine:114231] 
*/

USE [bodb_ost]
GO
/****** Object:  Synonym [dbo].[league]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[league] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[league] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[match]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[match] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[match] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[match_remark]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[match_remark] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[match_remark] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[odds]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[odds] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[odds] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[OddsES]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[OddsES] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[OddsES] TO [bodbDownlineNetView] AS [dbo]
GO

USE [bodb02]
GO
/****** Object:  Synonym [dbo].[league]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[league] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[league] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[match]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[match] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[match] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[match_remark]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[match_remark] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[match_remark] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[odds]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[odds] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[odds] TO [bodbDownlineNetView] AS [dbo]
GO
/****** Object:  Synonym [dbo].[OddsES]    Script Date: 11/29/2019 10:38:44 AM ******/
GRANT SELECT ON [dbo].[OddsES] TO [bodbDownlineNet] AS [dbo]
GO
GRANT SELECT ON [dbo].[OddsES] TO [bodbDownlineNetView] AS [dbo]
GO
