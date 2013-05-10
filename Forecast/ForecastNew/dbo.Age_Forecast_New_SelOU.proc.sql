ALTER PROCEDURE [dbo].[Age_Forecast_New_SelOU]  
	@matchid int,  
	@agentid int = null,  
	@roleid int = 2,  
	@bettype int = 3
AS
/*  
Original: Age_Forecast_SelOU  
Task: Forecast for OU bettype.  
DB: DB052.bodb02  
Created: 20120328@Hurri  
Revisions:  
  
  
*/
SET NOCOUNT ON;
IF @roleid = 2
    BEGIN
		SELECT   x.liveindicator,
                 x.score + x.hdp AS offset,
                 sum(x.hometotal) AS 'ht',
                 sum(x.awaytotal) AS 'at',
                 sum(x.homewin) AS 'al',
                 sum(x.awaywin) AS 'hl'
        FROM     (SELECT   liveindicator,
                           hdp1 AS hdp,
                           0 AS score,
                           sum(hometotalA) AS hometotal,
                           sum(awaytotalA) AS awaytotal,
                           sum(homewinA) AS homewin,
                           sum(awaywinA) AS awaywin
                  FROM     bettrans_forecast_agent AS b WITH (NOLOCK)
                  WHERE    bettype = @bettype
                           AND b.matchid = @matchid
                           AND b.recommend = @agentid
                  GROUP BY liveindicator, hdp1, livehomescore + liveawayscore) AS x
        GROUP BY liveindicator, x.score + x.hdp;
    END
ELSE
    IF @roleid = 3
        BEGIN
            SELECT   x.liveindicator,
                     x.score + x.hdp AS offset,
                     sum(x.hometotal) AS 'ht',
                     sum(x.awaytotal) AS 'at',
                     sum(x.homewin) AS 'al',
                     sum(x.awaywin) AS 'hl'
            FROM     (SELECT   liveindicator,
                               hdp1 AS hdp,
                               0 AS score,
                               sum(hometotalM) AS hometotal,
                               sum(awaytotalM) AS awaytotal,
                               sum(homewinM) AS homewin,
                               sum(awaywinM) AS awaywin
                      FROM     bettrans_forecast_agent AS b WITH (NOLOCK)
                      WHERE    bettype = @bettype
                               AND b.matchid = @matchid
                               AND b.mrecommend = @agentid
                      GROUP BY liveindicator, hdp1, livehomescore + liveawayscore) AS x
            GROUP BY liveindicator, x.score + x.hdp;
        END
    ELSE
        IF @roleid = 4
            BEGIN
                SELECT   x.liveindicator,
                         x.score + x.hdp AS offset,
                         sum(x.hometotal) AS 'ht',
                         sum(x.awaytotal) AS 'at',
                         sum(x.homewin) AS 'al',
                         sum(x.awaywin) AS 'hl'
                FROM     (SELECT   liveindicator,
                                   hdp1 AS hdp,
                                   0 AS score,
                                   sum(hometotalS) AS hometotal,
                                   sum(awaytotalS) AS awaytotal,
                                   sum(homewinS) AS homewin,
                                   sum(awaywinS) AS awaywin
                          FROM     bettrans_forecast_agent AS b WITH (NOLOCK)
                          WHERE    bettype = @bettype
                                   AND b.matchid = @matchid
                                   AND b.srecommend = @agentid
                          GROUP BY liveindicator, hdp1, livehomescore + liveawayscore) AS x
                GROUP BY liveindicator, x.score + x.hdp;
            END
GO
GRANT EXECUTE ON [dbo].Age_Forecast_New_SelOU TO [bodbDownlineNet];
GO
GRANT EXECUTE ON [dbo].Age_Forecast_New_SelOU TO [bodbDownlineNetView];