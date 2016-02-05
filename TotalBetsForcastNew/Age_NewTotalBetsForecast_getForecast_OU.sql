alter PROCEDURE Age_NewTotalBetsForecast_getForecast_OU
(
	@WinlostScore VARCHAR(MAX) =  NULL
	, @BetTypeID SMALLINT = null
	, @ColName_1	VARCHAR(30)  OUTPUT
	, @ColName_2	VARCHAR(30)  OUTPUT
	, @ColName_3	VARCHAR(30)  OUTPUT
	
)
AS 
/*      
	Created By: Helen
	Created Date: 20151223
	Task: 	Task: New Total Bet & Forecast [Redmine: 42116] 
	DB: DBAGE/bodb02
	
*/	
BEGIN
	
	CREATE TABLE #Temp1 (Score SMALLINT, Betchoice1 MONEY, Betchoice2 MONEY)
	
	DECLARE @DocHandler INT      
	    
	-- For read xml           
	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @WinlostScore      
	    
	INSERT INTO #Temp1(Score,Betchoice1,Betchoice2)
	SELECT   Data.Score,     
			 Data.BetChoice1,Data.BetChoice2         
	FROM OPENXML (@DocHandler, '/ROOT/Row',1)       
	WITH (  Score SMALLINT,     
			BetChoice1  MONEY, BetChoice2 MONEY   
	) AS Data      
	  
	EXEC sp_xml_removedocument @DocHandler      

	
	
	DECLARE @Col1 VARCHAR(30) = '' 
	DECLARE @Col2 VARCHAR(30) = ''
	DECLARE @Col3 VARCHAR(30) = ''

	DECLARE @Col1ValueHome MONEY
	DECLARE @Col1ValueAway MONEY

	DECLARE @Col2ValueHome MONEY
	DECLARE @Col2ValueAway MONEY

	DECLARE @Col3ValueHome MONEY
	DECLARE @Col3ValueAway MONEY

	DECLARE @Stop BIT = 0
	DECLARE @currentScore SMALLINT = 0
	DECLARE @minScore INT 
	DECLARE @MaxScore INT 
	
	-- Col2 processing
	SELECT @minScore = MIN(Score), @MaxScore = MAX (Score)
	FROM #Temp1
	
	
	IF (SELECT COUNT(DISTINCT Betchoice1) + COUNT(DISTINCT Betchoice2) FROM #Temp1 WHERE Score>=@minScore) = 2
	BEGIN
		DELETE FROM #Temp1 WHERE Score > @minScore
	END
		
	SELECT @minScore = MIN(Score), @MaxScore = MAX (Score)
	FROM #Temp1
	
	DECLARE @LeftSideIndex SMALLINT = 0
	DECLARE @RightSideIndex SMALLINT = 0
	
	DECLARE @ValueAway_tmp MONEY = 0
	DECLARE @ValueHome_tmp MONEY = 0
	
	DECLARE @ValueAway_tmp1 MONEY = 0
	DECLARE @ValueHome_tmp1 MONEY = 0
	
	DECLARE @Col_tmp SMALLINT = 0
	
	IF (@minScore = @MaxScore)
	BEGIN
		SELECT @Col1 = CAST(@minScore AS VARCHAR(2)),@Col2 = CAST(@minScore + 1 AS VARCHAR(2)),@Col3 = CAST(@minScore + 2 AS VARCHAR(2)) 
					,@Col1ValueAway = Betchoice2,@Col1ValueHome = Betchoice1 
					,@Col2ValueAway = Betchoice2,@Col2ValueHome = Betchoice1 
					,@Col3ValueAway = Betchoice2,@Col3ValueHome = Betchoice1 
		FROM #Temp1 WHERE Score = @minScore
		
	END 
	ELSE 
	BEGIN
	
		SELECT @Col1 = CAST(@minScore AS VARCHAR),@Col1ValueAway = Betchoice2,@Col1ValueHome = Betchoice1 
		FROM #Temp1 WHERE Score = @minScore
		
		SET @currentScore = @minScore + 1
		
		WHILE @Stop = 0 AND @currentScore <= @MaxScore
		BEGIN
			SELECT @Col2ValueHome=Betchoice1,@Col2ValueAway=Betchoice2
			FROM #Temp1 
			WHERE Score = @currentScore
			
			IF @Col1ValueHome <> @Col2ValueHome OR @Col1ValueAway <> @Col2ValueAway
			BEGIN
				SET @Stop = 1
				SET @Col2 = CAST(@currentScore AS VARCHAR(5))
				
				--PRINT @Col1
				SET @LeftSideIndex = @currentScore 
			END
			ELSE
			BEGIN
				SET @Col1 = @Col1 +' '+ CAST(@currentScore AS VARCHAR(2))
				--print @Col1
				--print @currentScore
			END	
			SET @currentScore = @currentScore + 1
		END
		
		--SELECT @Col1, @Col2,@COL3
		SET @Stop = 0
		
		SET @currentScore = @LeftSideIndex
		
		WHILE @Stop = 0 AND @currentScore < @MaxScore
		BEGIN
			SELECT @Col3ValueHome=Betchoice1,@Col3ValueAway=Betchoice2
			FROM #Temp1 
			WHERE Score = @currentScore + 1
			
			IF @Col2ValueHome <> @Col3ValueHome OR @Col2ValueAway <> @Col3ValueAway
			BEGIN
				SET @Stop = 1
				SET @Col3 = CAST(@currentScore + 1 AS VARCHAR(5))
			END
			ELSE
			BEGIN
				SET @currentScore = @currentScore + 1
				SET @Col2 = @Col2 +' '+ CAST(@currentScore AS VARCHAR)
				
			END	
		END
		
		
		IF @Col3 = ''
		BEGIN
			
			IF CHARINDEX(' ',@Col2) >= 1
			BEGIN
				-- get string after sencond space
				SET @Col3 =  @Col2
				-- get string after first space
				SET @Col2 = LEFT(@col2, CHARINDEX(' ', @Col2)-1)  
				SET @Col3 = RTRIM(LTRIM(REPLACE(@Col3,@Col2,'')))
				IF CHARINDEX(' ',@Col3) >= 1
					SET @Col3 = LEFT(@col3, CHARINDEX(' ', @Col3)-1)  
					
			END
			ELSE
			BEGIN
				SET @Col3 =  CAST(@currentScore + 1 AS VARCHAR(3))
				SET @Col3ValueAway = @Col2ValueAway
				SET @Col3ValueHome = @Col2ValueHome
			END
			
		END
		
	END
	
	DECLARE @SQLText NVARCHAR(MAX) = ''
	
	SET @ColName_1 = @Col1
	SET @ColName_2 = @Col2
	SET @ColName_3 = @Col3
		
	SELECT @BetTypeID AS BetType, 'h' AS BetTeam, @Col1ValueHome AS COL_1, @Col2ValueHome AS COL_2, @Col3ValueHome AS COL3 
	UNION ALL 
	SELECT @BetTypeID AS BetType,  'a', @Col1ValueAway AS COL_1, @Col2ValueAway AS COL_2, @Col3ValueAway AS COL3 
	
	DROP TABLE #Temp1	
END
GO
GRANT EXEC ON Age_NewTotalBetsForecast_getForecast_OU TO [bodbDownlineNet]
GO
GRANT EXEC ON Age_NewTotalBetsForecast_getForecast_OU TO [bodbDownlineNetView]
GO
