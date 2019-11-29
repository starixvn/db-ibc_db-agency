/*
Created: 20191129@Bobby
DB: DBOST.bodb_ost
Task: Deploy UAT - New Alpha forecast [Redmine:114231] 
*/

USE [master]
GO
/****** Object:  Login [bodbDownlineNet]    Script Date: 11/22/2019 5:56:20 PM ******/
CREATE LOGIN [bodbDownlineNet] WITH PASSWORD=N'Password_Here', DEFAULT_DATABASE=[bodb_ost], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON
GO

/****** Object:  Login [bodbDownlineNetView]    Script Date: 11/22/2019 5:56:20 PM ******/
CREATE LOGIN [bodbDownlineNetView] WITH PASSWORD=N'Password_Here', DEFAULT_DATABASE=[bodb_ost], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON
GO

USE [bodb_ost]
GO
CREATE USER [bodbDownlineNet] FOR LOGIN [bodbDownlineNet]
GO
EXEC sp_addrolemember N'db_datareader', N'bodbDownlineNet'
GO

CREATE USER [bodbDownlineNetView] FOR LOGIN [bodbDownlineNetView]
GO
EXEC sp_addrolemember N'db_datareader', N'bodbDownlineNet'
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
