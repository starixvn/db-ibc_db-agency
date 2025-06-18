/*<info serverAlias="DBSIC-bodb02"></info>*/

-- Created: 20250617@Bobby
-- DB: DBSIC-bodb02
-- Task: Correct SMA Super Level - [Redmine : #230937]
-- This script is used to correct the SMA Super Level discrepancies in the transfer records
-- It updates the transfer table with the correct mrecommend value from the customer table

use [bodb02]
GO
DROP TABLE IF EXISTS #TempTransfer;
-- This script is used to identify discrepancies in the transfer records
CREATE TABLE #TempTransfer (
    transid BIGINT NOT NULL,
    custid INT NOT NULL,
    roleid INT NOT NULL,
    recommend INT NOT NULL,
    mrecommend INT NOT NULL,
    srecommend INT NOT NULL,
    winlostdate DATE NOT NULL,
    bettype INT NOT NULL
);
-- Insert data into the temporary table from the transfer table
INSERT INTO #TempTransfer (
    transid, custid, roleid
    , recommend, mrecommend, srecommend, winlostdate, bettype
)
SELECT t.transid, t.custid, c.roleid
    --, t.recommend, t.mrecommend, t.srecommend, t.winlostdate, t.bettype
    , c.recommend AS cust_recommend, c.mrecommend AS cust_mrecommend, c.srecommend AS cust_srecommend
    , t.winlostdate, t.bettype
FROM [transfer] t WITH (NOLOCK)
inner JOIN [CustDB].dbo.customer c WITH(NOLOCK) ON t.custid = c.custid 
WHERE t.winlostdate >= '2025-06-18' AND t.bettype > 31000 and t.Currency = 20
and (
    t.recommend <> c.recommend OR 
    t.mrecommend <> c.mrecommend OR 
    t.srecommend <> c.srecommend
)
-- Update the transfer table with mrecommend from the temp table
UPDATE t
SET t.mrecommend = temp.mrecommend, t.RepUpdateTime = SYSDATETIME()
FROM [transfer] t WITH (ROWLOCK, UPDLOCK)
INNER JOIN #TempTransfer temp ON t.transid = temp.transid;
