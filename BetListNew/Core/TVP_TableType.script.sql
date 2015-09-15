USE [bodb02]
GO


CREATE TYPE [dbo].[TVP_BetTicketStatus] AS TABLE
(
	[StatusID] [TINYINT] NULL
)
GO

CREATE TYPE [dbo].[TVP_SportBettypeMatrix] AS TABLE
(
	ProductID 		TINYINT
	, Bettype 		SMALLINT
	, EventType 	TINYINT
	, SubProduct 	VARCHAR(500)
)
GO

CREATE TYPE [dbo].[TVP_TicketSportBettype] AS TABLE
(
	TransID			BIGINT
	, Refno			BIGINT
	, CustID 		INT 
	, ProductID 	TINYINT
	, Bettype 		SMALLINT	
	, EventType		TINYINT
	, WhTicket		TINYINT
)
GO

USE bodb_archive
GO

CREATE TYPE [dbo].[TVP_BetTicketStatus] AS TABLE
(
	[StatusID] [TINYINT] NULL
)
GO

CREATE TYPE [dbo].[TVP_SportBettypeMatrix] AS TABLE
(
	ProductID 		TINYINT
	, Bettype 		SMALLINT
	, EventType 	TINYINT
	, SubProduct 	VARCHAR(500)
)
GO

CREATE TYPE [dbo].[TVP_TicketSportBettype] AS TABLE
(
	TransID			BIGINT
	, Refno			BIGINT
	, CustID 		INT 
	, ProductID 	TINYINT
	, Bettype 		SMALLINT	
	, EventType		TINYINT
	, WhTicket		TINYINT
)
GO
