/*<info serverAlias="DBMSG-bodb_Message"></info>*/
/*
	Created: 20230921@Bobby
	DB: DBMSG-bodb_Message
	Task: AutoJob Enhancement - [Redmine : #193021]
*/
--DBMSG
use bodb_Message;
go
CREATE TABLE dbo.ToastType (
	TypeId	TINYINT,
	TypeName	VARCHAR(100),
	TypeDesc	NVARCHAR(250),
	CONSTRAINT PK_TypeId PRIMARY KEY CLUSTERED (TypeId)
)
ON [DATA];
GO

CREATE TABLE dbo.ToastSiteFunction (	
	SiteFunctionId		TINYINT,
	SiteFunctionName	VARCHAR(100),
	SiteFunctionDesc	NVARCHAR(250),
	CONSTRAINT PK_SiteFunctionId PRIMARY KEY CLUSTERED (SiteFunctionId)
)
ON [DATA];
GO

CREATE TABLE dbo.ToastMessage (
	ToastId	INT IDENTITY(1, 1),
	TargetId	INT NOT NULL,
	TypeId		TINYINT NOT NULL,
	SiteFunctionId	TINYINT NOT NULL,
	Content_en	NVARCHAR(4000),
	Content_ch	NVARCHAR(4000),
	Content_cs	NVARCHAR(4000),
	Content_jp	NVARCHAR(4000),
	Content_it	NVARCHAR(4000),
	Content_th	NVARCHAR(4000),
	Content_ko	NVARCHAR(4000),
	Content_es	NVARCHAR(4000),
	Content_vn	NVARCHAR(4000),
	Content_id	NVARCHAR(4000),
	Content_el	NVARCHAR(4000),
	Content_mx	NVARCHAR(4000),
	Creator	INT NOT NULL,
	CreatedTime	DATETIME,
	ExtraInfo	NVARCHAR(4000), --- JSON format({"read":[{"sub":1,"seen": "yyyy-MM-dd hh:mm:ss"}]})
	ExpireTime	DATETIME,
	CONSTRAINT PK_ToastId PRIMARY KEY NONCLUSTERED (ToastId)
)
ON [DATA];
GO

CREATE CLUSTERED INDEX CIX_ToastMessage  ON dbo.ToastMessage(TargetId, CreatedTime) ON [INDEX];
GO

--- TODO: Seed data
INSERT INTO dbo.ToastType (TypeId, TypeName, TypeDesc)
VALUES
(1, 'info', 'Toast informaion message'),
(2, 'successful', 'Toast successful message'),
(3, 'warning', 'Toast warning message'),
(4, 'error', 'Toast error message')

GO
INSERT INTO dbo.ToastSiteFunction(SiteFunctionId, SiteFunctionName, SiteFunctionDesc)
VALUES
(1, 'Age_AutoTransfer_Failed', 'Alpha auto transfer process failed'),
(2, 'Age_ADBT_Config', 'NAP/Alpha Update ADBT Config')
GO
