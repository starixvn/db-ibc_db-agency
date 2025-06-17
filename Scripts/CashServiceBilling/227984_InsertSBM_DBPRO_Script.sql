/*<info serverAlias="DBPRO-bodb02"></info>*/
/*
	Created: 20250610@Bobby
	DB: DBPRO-bodb02
	Task: Setup Cash Serivce Billing - [Redmine : #229914]
*/

USE [bodb02]
GO

-- Insert into SportBettypeMatrix for each bettype
INSERT INTO [dbo].[SportBettypeMatrix] (
    [SportType], [BetType], [IsLive], [ProductID], [Enabled], [EventType], [RefTable]
) VALUES
    (0, 31001, 0, 111, 1, 0, 4), -- Deposit
    (0, 31002, 0, 111, 1, 0, 4), -- Withdrawal
    (0, 31003, 0, 111, 1, 0, 4), -- Cash Services fee
    (0, 31004, 0, 111, 1, 0, 4), -- Free period
    (0, 31005, 0, 111, 1, 0, 4), -- Transaction Fee
    (0, 31006, 0, 111, 1, 0, 4); -- Promotion
    