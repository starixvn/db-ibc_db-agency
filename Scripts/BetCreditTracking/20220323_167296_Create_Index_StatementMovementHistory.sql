/*<info serverAlias="DBBAH-bodb02"></info>*/
/*
	Created: 20220323@Sol
	DB: DBBAH-bodb02
	Task: create index in table [StatementMovementHistory] - [Redmine : #167296]
*/

USE bodb02;

GO

CREATE CLUSTERED INDEX CIX_StatementMovementHistory ON [dbo].[StatementMovementHistory]
(
	[CustId] ASC,
	[BetType] ASC
)

GO

CREATE NONCLUSTERED INDEX IX_WinlostDate ON [dbo].[StatementMovementHistory]
(
	[WinlostDate] ASC
)
GO