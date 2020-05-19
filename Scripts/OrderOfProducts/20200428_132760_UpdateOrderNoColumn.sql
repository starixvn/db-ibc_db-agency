/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

/*
	Created: 20200428@Malcolm
	DB: DBPRO.bodb02
	Task: update OrderNo column [Redmine : #132760]
*/

CREATE TABLE #M (ProductName VARCHAR(50), OrderNo INT)

INSERT INTO #M (ProductName, OrderNo)
VALUES  ('Sportsbook',10),
		('Saba Promotion',20),
		('Number Game',30),
		('NG2',40),
		('Indo 4D',50),
		('Lottery',60),
		('RNG Keno',70),
		('Table Game',80),
		('Virtual Games',90),
		('Virtual Sports',100),
		('Fishing World',110),
		('Saba.Club',120),
		('Allbet',130),
		('BBIN',140),
		('Gold Deluxe',150),
		('SA Gaming',160),
		('Sexy Gaming',170),
		('AG Casino',180),
		('IBCBet Live Casino',190),
		('Macau Games',200),
		('RNG Casino',210),		
		('Card Club',220),
		('Macau',230),
		('SG',240),
		('PP',250)

UPDATE t 
SET  t.OrderNo = m.OrderNo
FROM Products t
	INNER JOIN #M m ON t.ProductName = m.ProductName