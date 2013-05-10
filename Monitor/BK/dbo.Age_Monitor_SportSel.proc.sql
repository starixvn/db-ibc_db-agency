ALTER PROCEDURE Age_Monitor_SportSel  
	@custid INT,
	@Language NVARCHAR(2) = 'E'  	 
AS    
/*    
Created:    
Task:    
DB: DB05.bodb02    
Original: SportSelForMonitor  
    
Revisions:     
 - 20101020@Simon: Sport are running.  
 - 20101117@Johnson: add parameter @custid to select Sports running of this agent are enabled	
 - 20101209@Johnson: Just select sport running and have a ticket bet
 - 20110105@Johnson: get sports by setting
 - 20110208@Amy: get sportname by language
*/    
    
SET NOCOUNT ON   
 
DECLARE @DisableHR BIT ,
	@DisableNumber	BIT
	--@Disable152 BIT, --Greyhound
	--@Disable153 BIT
--DECLARE @roleid INT
DECLARE @tmpSports TABLE(sporttype INT)

SELECT @DisableHR = CASE WHEN DisableHorseRacing = 0 THEN 0
						WHEN DisableOpenTote = 0 THEN 0 ELSE 1 END,
	@DisableNumber = DisableNumber
	--@Disable152	= CASE WHEN Disable152_UK = 0 THEN Disable152_UK else Disable152_AU END,
	--@Disable153 = Disable153_AU
	FROM Custinfo WITH(NOLOCK)
	WHERE custid = @custid


INSERT INTO @tmpSports
SELECT DISTINCT sporttype 
FROM custsetting WITH(NOLOCK)
WHERE custid = @custid

IF @DisableHR = 0
INSERT INTO @TmpSports
SELECT 151 -- Horse racing

--IF @Disable152 = 0
--INSERT INTO @TmpSports
--SELECT 152	-- Greyhound

--IF @Disable153 = 0
--INSERT INTO @TmpSports
--SELECT 153 -- Harness

IF @DisableNumber = 0
INSERT INTO @TmpSports
SELECT 161 --Number Game

	
SELECT s.sporttype ,
	CASE @Language 
	WHEN 'E' THEN s1.sportname
	WHEN 'CS' THEN (case when s1.sportnamecs= '' or s1.sportnamecs is null then s1.sportname else s1.sportnamecs end)
	WHEN 'CT' THEN (case when s1.sportnamech= '' or s1.sportnamech is null then s1.sportname else s1.sportnamech end)
	WHEN 'TH' THEN (case when s1.sportnameth = '' or s1.sportnameth is null then s1.sportname else s1.sportnameth end)
	WHEN 'J' THEN (case when s1.sportnamejp= '' or s1.sportnamejp is null then s1.sportname else s1.sportnamejp end)
	WHEN 'KO' THEN (case when s1.sportnameko= '' or s1.sportnameko is null then s1.sportname else s1.sportnameko end)
	ELSE s1.sportname			
	END	 as sportname
FROM @tmpSports s
INNER JOIN Sports s1 WITH(NOLOCK) ON s.sporttype = s1.sporttype
ORDER BY s.sporttype

GO
GRANT EXECUTE ON [dbo].Age_Monitor_SportSel TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].Age_Monitor_SportSel TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].Age_Monitor_SportSel TO [vnteam]
GO



