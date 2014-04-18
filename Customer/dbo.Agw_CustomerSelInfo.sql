ALTER PROCEDURE [Agw_CustomerSelInfo]
@CustID int

AS

/*
Created: 20080909@QuiNV
Task: Get basic information of a customer (belonging have been checked on web already)
DB: DB05.bodb02
Original:


Revisions:
    - 20090417@[Lee]: [Add 2 return values for Casino] 
	- 20090710@Phuc: unhide IP for TB currency.
	- 20100413@Kiwi: Get transferoption from CustSuper/CustMaster/CustAgent
	- 20100513@Terry: Get Disable Open Tote Status
	- 20100928@Johnson: get DisableNumber, DisableBingo and SyncBingo column
	- 20110303@Simon: get Disable151_51, Disable152_41, Disable152_51 and Disable153_51 column
	- 20110307@Lukas: get DisableAutoMPT
	- 20120817@Sophia: get DisableVirtualSports, HideVirtualSports
	- 20120926@Sophia: Get DoubleCommLosing
	- 20140303@Kathy: Get HideKeno [Redmine:#12691]

*/

SET NOCOUNT ON

DECLARE @RoleID TINYINT, @TransferOption varchar(8), @DisableAutoMPT BIT

SELECT @RoleID = RoleID FROM custinfo WITH (NOLOCK) WHERE custid = @CustId

IF (@RoleID = 4)
BEGIN 
	SELECT @TransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
	FROM CustSuper  WITH (NOLOCK) 
	WHERE custid = @CustId
END
ELSE IF (@RoleID = 3)
BEGIN 
	SELECT @TransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0)),
		   @DisableAutoMPT = DisableAutoMPT
	FROM CustMaster  WITH (NOLOCK) 
	WHERE custid = @CustId
END
ELSE IF (@RoleID = 2)
BEGIN 
	SELECT @TransferOption = dbo.F_Decimal_Binary(ISNULL(TransferOption,0))
	FROM CustAgent  WITH (NOLOCK) 
	WHERE custid = @CustId
END

SELECT c.username, 
		firstname, 
		lastname, 
 		iplogin, 
		closed, 
		reject as suspended, 
		c.roleid as roleid, 
		ISNULL(@TransferOption,0) as transferoption,
		ISNULL(@DisableAutoMPT,0) as DisableAutoMPT,
		ci.DisableHorseRacing as Disable151_31, 
		ci.DisableOpenTote as Disable151_41,
		ci.Disable151_AU as Disable151_51,
		ci.Disable152_UK as Disable152_41,
		ci.Disable152_AU as Disable152_51,
		ci.Disable153_AU as Disable153_51,
		ci.DisableFinancial,
		ci.DisableOutright,
		ci.disablecasino,
		ci.DisableBingo,
		ci.DisableNumber,
		ci.DisableVirtualSports,
		ci.synccasino,
		ci.syncBingo,
		ci.HideVirtualSports,
		ci.currency,
		ci.credit,
		ci.DoubleCommLosing,
		ci.HideKeno
FROM Customer c with(nolock) 
INNER JOIN Custinfo ci with(nolock) ON c.CustID = ci.CustID
WHERE c.CustID = @CustID

GO
GRANT EXECUTE ON [dbo].[Agw_CustomerSelInfo] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_CustomerSelInfo] TO [vnteam]