/*<info serverAlias="DBAGE-bodb02"></info>*/
/*
	Created:20250507@Bobby
	Task: Alpha - Tuning index on bettransXXX [Redmine: #226284]
	DB: DBAGE-bodb02
*/
USE [bodb02]
GO

/****** Object:  Index [IX_recommend]    Script Date: 5/7/2025 11:54:21 AM ******/
CREATE NONCLUSTERED INDEX [IX_recommend] ON [dbo].[bettransLC]
(
	[recommend] ASC,
	[winlostdate] ASC
)
INCLUDE([gameID],[productID],[RefNo],[statusID],[currency],[winlost],[actual_stake],[playercomm],[awinlost],[comm],[custid],[stake],[apositiontaking],[actualrate],[NetStake],[discount]) 
WITH (ONLINE = ON, DROP_EXISTING = ON) ON [bettransLC_index]
GO

/****** Object:  Index [IX_recommend]    Script Date: 5/7/2025 11:56:25 AM ******/
CREATE NONCLUSTERED INDEX [IX_recommend] ON [dbo].[bettransRnG]
(
	[recommend] ASC,
	[winlostdate] ASC
)
INCLUDE([gameID],[productID],[RefNo],[statusID],[currency],[winlost],[actual_stake],[playercomm],[awinlost],[comm],[custid],[stake],[apositiontaking],[actualrate],[BetStake],[discount]) 
WITH (ONLINE = ON, DROP_EXISTING = ON) ON [bettransRnG_index]
GO