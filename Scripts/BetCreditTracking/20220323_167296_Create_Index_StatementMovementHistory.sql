/*<info serverAlias="DBBAH-bodb02"></info>*/
/*
	Created: 20220323@Sol
	DB: DBBAH-bodb02
	Task: create index in table [StatementMovementHistory] - [Redmine : #167296]
*/

USE bodb02;

GO

CREATE NONCLUSTERED INDEX IX_CustId_WlDate_OldWlDate ON [dbo].[StatementMovementHistory]
(
	[CustId] ASC,
	[WinlostDate] ASC,
	[OldWinlostDate] ASC
)
INCLUDE([MatchId],[TransId],[Winlost],[ActualStake],[PlayerComm],[Bettype])
GO


