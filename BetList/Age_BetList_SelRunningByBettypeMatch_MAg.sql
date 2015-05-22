USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelRunningByBettypeMatch_MAg]
	@matchid int,
	@custid int,
	@bettype int,
	@Language varchar(2) = 'E',
	@liveindicator int =0,
	@betteam nvarchar(20) = NULL
AS
/*
Created: 
Task : Betlist
DB: bodb_AGE.bodb02
Original: BetsSelBetListMatchWinLoss_MAg
Revisions:    
    - 20080105: Add typenamee2,sportname 
    - 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
    - 20081030@QuangVinh: Add more result for Horseracing 
    - 20090406@HanhVu: remove refno
    - 20090416@Minh: remove indexName
    - 20090605@HiepVo: remove Horse racing bettype
    - 20090618@AnhPham: Remove 'Customer' table
	- 20090710@Phuc: unhide IP for TB currency. 
   	- 20090930@Phuc: get oddstype.
   	-- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
   	- 20101123@Jacob: Add column betid in select clause
   	- 20110408@Amy: Change function to get Odds value and showed odds type
	- 20110415@Viet: temporary remove liveindicator's condition
	- 20110418@Jamie: Check liveindicator for Number Game only 
	- 20110516@Johnson: Apply new arrange bettype
	- 20110810@Sophia: Add new parametter @betteam
	- 20110811@Sophia: Add new columns actual_stake and modds
	- 20110930@Johnson: Get column matchid into betlist
	- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
	- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
	- 20120120@Sophia: Add refno, showtime for Table - Shoe - Hand of LiveCasino 
						Add Sub table for Live Casino
	- 20120705@Sophia: Get sporttype for outright
	- 20120926@Sophia: Get Comstatus
	- 20140425@Dom: Group TB and FGLG
	- 20150416@Tom: Integrate new 60 bet types from BetRadar (32734)
	- 20150522@Bobby: Rollback code caused by holding core bet list
*/
BEGIN
	SET NOCOUNT ON
	if @bettype in (10)
	BEGIN
		SELECT 
			l.Sporttype,
			b.Username,      		
			b.Bettype,     
			b.TransID,   
			0 as matchid,  
			m.Matchcode,
			m.GroupMatch as Race, 
			m.leagueid,
			m.TeamID as HomeID,
			0 as AwayID, 
			0 as hdp1,--hdp1, 
			0 as hdp2,--hdp2, 
			b.odds,
			b.modds,   
			b.status,     
			b.stake,  
			b.actual_stake,
			b.Transdate,  		
			'' as Betteam,--Betteam,    
			0 as Liveindicator,--b.Liveindicator,
			0 as Livehomescore,--b.Livehomescore, 
			0 as Liveawayscore,--b.Liveawayscore, 		 				
			b.APositiontaking,  		
			b.MPositiontaking,		
			b.discount as Adiscount,--Agent
			b.adiscount as Mdiscount,--Master
			b.IP as IP,
			CONVERT(BIT,0) as IsNeutral,
			0 as oddstype,
			b.betid,
			'' as showtime,
			b.refno,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		FROM 
			Bettrans b with (nolock)
			INNER JOIN outright m with (nolock) on b.matchid=m.orid		
			INNER JOIN league l with (nolock) on m.leagueid = l.leagueid
		WHERE
			b.matchid=@matchid and 
			b.MRecommend=@custid  and 
			
			b.bettype=@bettype and
			--b.status='running'  
			b.statusID=0 
		ORDER BY
			b.status, b.transid
		RETURN
	END
	if @bettype< 19001
	BEGIN
		SELECT 
			m.sporttype,
			b.Username,      		
			b.Bettype,     
			b.TransID,    
			m.matchid, 
			m.Matchcode, 
			'' as Race,
			m.leagueid,
			m.HomeID,
			m.AwayID, 
			convert(float, b.hdp1) as hdp1, 
			convert(float, b.hdp2) as hdp2, 
			b.odds,
			b.modds,
			CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					 ELSE b.status 
					 END as status,      
			b.stake, 
			b.actual_stake, 
			b.Transdate,  		
			b.Betteam,    
			b.Liveindicator,
			b.Livehomescore, 
			b.Liveawayscore, 		 	
			b.APositiontaking,  
			b.MPositiontaking,
			b.discount as Adiscount,--Agent
			b.adiscount as Mdiscount,--Master
			b.IP as IP,
			isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
			b.oddsType,
			b.betid,
			m.showtime,
			b.refno,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		FROM 
			Bettrans b with (nolock) 
			inner join Match m with (nolock) on b.matchid=m.matchid 		
		WHERE
			b.matchid=@matchid and 
			b.MRecommend=@custid  and 
			( 
				(@bettype=6 AND b.bettype IN(6,126)) 
				OR (@bettype=14 and b.bettype IN(14,127)) 
				OR (@bettype=2 and b.bettype IN(2,157)) 
				OR (@bettype=15 and b.bettype IN(15,167)) 
				OR bettype = @bettype 
				) and
			--b.bettype=@bettype and
			--b.status in ('waiting','running')  
			b.statusID in (0,1) and 
			b.Liveindicator= CASE WHEN m.sporttype = 161 THEN @liveindicator ELSE b.liveindicator END and 
			ISNULL(b.betteam,'') = CASE WHEN m.sporttype = 161 AND ISNULL(@Betteam, '') <> '' THEN @betteam ELSE ISNULL(b.betteam,'') END 
		ORDER BY
			status, b.transid
	END


	---Live Casino
	IF @Bettype BETWEEN 1101 AND 1199
	BEGIN 
		SELECT 
			bg.refno, 
			bg.odds, 
			bg.stake,
			bg.status ,
			bg.apositiontaking, 
			bg.mpositiontaking, 
			bg.spositiontaking,
			bg.betteam  
		FROM bettransg bg with (NOLOCK)
		INNER JOIN bettrans B  with (NOLOCK)ON bg.refno = B.refno
		WHERE	bg.matchid=@matchid and 
				b.MRecommend=@custid  and 
				b.statusID in (0,1) and 		
				b.bettype=@bettype 

	END 
END
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelRunningByBettypeMatch_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelRunningByBettypeMatch_MAg] TO [vnteam]