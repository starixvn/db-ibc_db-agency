 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Monitor_BetlistSel]    Script Date: 02/10/2011 05:50:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_xtest]
 @custid            INT,
 @sporttypegroup    TINYINT = 0,
 @Bettypegroup      TINYINT = 0,
 @leagueid          NVARCHAR(4000) = '',  
 @transid           BIGINT = 0,
 @Language          VARCHAR(2) = 'E',
 @LimitRowCount     INT = 10,
 @winlostdate       SMALLDATETIME
AS
BEGIN

	--SET NOCOUNT ON	
	
	IF @sporttypegroup =0 -- get all sports
	BEGIN
		exec Age_Monitor_BetlistSelAllSports 
            @custid=@custid,
            @Bettypegroup=@Bettypegroup,
            @leagueid=@leagueid,
            @transid=@transid,
            @Language=@Language,
            @LimitRowCount=@LimitRowCount,
            @winlostdate=@winlostdate
	END
	ELSE IF @sporttypegroup =1 -- soccer
	BEGIN
		exec Age_Monitor_BetlistSelBySoccer 
            @custid=@custid,
            @Bettypegroup=@Bettypegroup,
            @leagueid=@leagueid,
            @transid=@transid,
            @Language=@Language,
            @LimitRowCount=@LimitRowCount,
            @winlostdate=@winlostdate
	END
	ELSE -- others		
	BEGIN
	    exec Age_Monitor_BetlistSelByOtherSports 
            @custid=@custid,
            @Bettypegroup=@Bettypegroup,
            @leagueid=@leagueid,
            @transid=@transid,
            @Language=@Language,
            @LimitRowCount=@LimitRowCount,
            @winlostdate=@winlostdate
	END
END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_xtest] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_xtest] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_xtest] TO [vnteam]