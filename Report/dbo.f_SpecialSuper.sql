use bodb02
go 

CREATE FUNCTION [dbo].[f_SpecialSuper] 
()
RETURNS TABLE
RETURN
/*
	Created: Sophia
	Date: 20160713
	Task: Return srecommend of Special Line which want to hide winloss report [Redmine: #60767]
	DB: DBAGE/BODB02

*/

--K9 (5453438)
--K8 (12264821)
--KSS (14719658)

SELECT 5453438  AS srecommend
UNION ALL 
SELECT 12264821   
UNION ALL
SELECT 14719658   



GO 
GRANT SELECT ON [dbo].[f_SpecialSuper] TO [bodbDownlineNet]
GO 
GRANT SELECT ON [dbo].[f_SpecialSuper] TO [bodbDownlineNetView]
GO 
