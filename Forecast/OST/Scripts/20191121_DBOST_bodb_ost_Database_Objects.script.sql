USE [bodb_ost]
GO
/****** Object:  Synonym [dbo].[league]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE SYNONYM [dbo].[league] FOR [bodb02].[dbo].[league]
GO
/****** Object:  Synonym [dbo].[match]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE SYNONYM [dbo].[match] FOR [bodb02].[dbo].[match]
GO
/****** Object:  Synonym [dbo].[match_remark]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE SYNONYM [dbo].[match_remark] FOR [bodb02].[dbo].[match_remark]
GO
/****** Object:  Synonym [dbo].[odds]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE SYNONYM [dbo].[odds] FOR [bodb02].[dbo].[odds]
GO
/****** Object:  Synonym [dbo].[OddsES]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE SYNONYM [dbo].[OddsES] FOR [bodb02].[dbo].[OddsES]
GO
/****** Object:  Table [dbo].[bettrans]    Script Date: 11/21/2019 1:26:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[bettrans](
	[transid] [bigint] IDENTITY(333242000,1) NOT FOR REPLICATION NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[awinlost] [money] NULL,
	[mwinlost] [money] NULL,
	[playercomm] [money] NULL,
	[comm] [money] NULL,
	[acomm] [money] NULL,
	[apositiontaking] [smallmoney] NULL,
	[mpositiontaking] [smallmoney] NULL,
	[tpositiontaking] [smallmoney] NULL,
	[playerdiscount] [decimal](9, 8) NULL,
	[discount] [decimal](9, 8) NULL,
	[adiscount] [decimal](9, 8) NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NOT NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](1) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[oddsspread] [money] NULL,
	[actualrate] [float] NULL,
	[matchid] [int] NULL,
	[recommend] [int] NOT NULL,
	[mrecommend] [int] NOT NULL,
	[ruben] [tinyint] NULL,
	[betid] [bigint] NULL,
	[statuswinlost] [tinyint] NULL,
	[modds] [smallmoney] NULL,
	[bettype] [smallint] NULL,
	[betdaqid] [bigint] NULL,
	[tstamp] [timestamp] NULL,
	[actual_stake] [money] NULL,
	[currency] [tinyint] NULL,
	[ip] [nvarchar](15) NULL,
	[transdesc] [nvarchar](1000) NULL,
	[sdiscount] [decimal](9, 8) NULL,
	[scomm] [money] NULL,
	[spositiontaking] [smallmoney] NULL,
	[swinlost] [money] NULL,
	[srecommend] [int] NOT NULL,
	[Username] [nvarchar](50) NULL,
	[CurrencyName] [nvarchar](50) NULL,
	[virtualrate] [float] NOT NULL,
	[oddstype] [tinyint] NULL,
	[statusID] [tinyint] NULL,
	[currency2] [tinyint] NULL,
	[balance] [money] NULL,
	[SecAcceptFlag] [bit] NULL,
	[transid2] [bigint] NULL,
	[recommdate] [datetime] NULL,
	[ExtraInfo] [varchar](1000) NULL,
	[WalletType] [tinyint] NULL,
	[BonusID] [int] NULL,
	[RefCode] [bigint] NULL,
	[SettlementTime] [datetime] NULL,
	[epositiontaking] [smallmoney] NULL,
 CONSTRAINT [PK_bettrans] PRIMARY KEY CLUSTERED 
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bettrans_index3]
) ON [bettrans_index3]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_betrunning_mrecommend]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE NONCLUSTERED INDEX [IX_betrunning_mrecommend] ON [dbo].[bettrans]
(
	[mrecommend] ASC,
	[bettype] ASC,
	[matchid] ASC
)
INCLUDE ( 	[odds],
	[stake],
	[mpositiontaking],
	[livehomescore],
	[liveawayscore],
	[liveindicator],
	[betteam],
	[spositiontaking],
	[actual_stake],
	[recommend],
	[custid],
	[Username],
	[refno],
	[transid],
	[betid],
	[hdp1],
	[hdp2],
	[modds],
	[SecAcceptFlag],
	[checktime],
	[status],
	[transdate],
	[apositiontaking],
	[tpositiontaking],
	[discount],
	[adiscount],
	[sdiscount],
	[ip],
	[oddstype],
	[comstatus],
	[betcheck],
	[oddsspread],
	[currency]) 
WHERE ([statusID] IN ((0), (1)))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bettrans_index1]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_betrunning_recommend]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE NONCLUSTERED INDEX [IX_betrunning_recommend] ON [dbo].[bettrans]
(
	[recommend] ASC,
	[bettype] ASC,
	[matchid] ASC
)
INCLUDE ( 	[odds],
	[stake],
	[apositiontaking],
	[livehomescore],
	[liveawayscore],
	[liveindicator],
	[betteam],
	[custid],
	[actual_stake],
	[mpositiontaking],
	[spositiontaking],
	[Username],
	[refno],
	[transid],
	[betid],
	[hdp1],
	[hdp2],
	[modds],
	[SecAcceptFlag],
	[checktime],
	[status],
	[transdate],
	[tpositiontaking],
	[discount],
	[adiscount],
	[sdiscount],
	[ip],
	[oddstype],
	[comstatus],
	[betcheck],
	[oddsspread],
	[currency],
	[ExtraInfo]) 
WHERE ([statusID] IN ((0), (1)))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bettrans_index1]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_betrunning_srecommend]    Script Date: 11/21/2019 1:26:00 PM ******/
CREATE NONCLUSTERED INDEX [IX_betrunning_srecommend] ON [dbo].[bettrans]
(
	[srecommend] ASC,
	[bettype] ASC,
	[matchid] ASC
)
INCLUDE ( 	[odds],
	[stake],
	[livehomescore],
	[liveawayscore],
	[liveindicator],
	[betteam],
	[spositiontaking],
	[custid],
	[mpositiontaking],
	[actual_stake],
	[mrecommend],
	[recommend],
	[Username],
	[refno],
	[transid],
	[betid],
	[hdp1],
	[hdp2],
	[modds],
	[SecAcceptFlag],
	[checktime],
	[status],
	[transdate],
	[apositiontaking],
	[tpositiontaking],
	[discount],
	[adiscount],
	[sdiscount],
	[ip],
	[oddstype],
	[comstatus],
	[betcheck],
	[oddsspread],
	[currency]) 
WHERE ([statusID] IN ((0), (1)))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [bettrans_index1]
GO
ALTER TABLE [dbo].[bettrans] ADD  CONSTRAINT [DF_bettrans_epositiontaking]  DEFAULT ((0)) FOR [epositiontaking]
GO
