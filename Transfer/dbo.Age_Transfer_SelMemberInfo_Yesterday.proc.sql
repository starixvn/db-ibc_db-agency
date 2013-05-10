ALTER PROC [dbo].[Age_Transfer_SelMemberInfo_Yesterday]
	@custid int,--member 
	@IsAllowTotalBalance bit = null,
	@username varchar(20) OUTPUT,--member 
	@syncCasino BIT = 0 OUTPUT ,
	@DisableCasino BIT = 0 OUTPUT,
	@CashBalance money OUTPUT,
	@Oustanding money OUTPUT,
	@GivenCredit money OUTPUT,
	@BetCredit money OUTPUT,
	@LastLogin datetime OUTPUT,
	@Balance money OUTPUT,
	@MaxTransDate datetime OUTPUT,
	@FutureBetCredit money OUTPUT,
	@AmtTransferred money = 0 OUTPUT
AS
/*
Created: ???
Task : 
DB: DB05.bodb02
Original: Age_Transfer_SelMemberInfo_Yesterday_1
	Revisions:
		- 20090505@Phuc: get amount transferred.
		- 20100105@Jamie: Remove exchange table out and @currency param 
		- 20101224@Johnson: Apply new arrange of bettype
		- 20110111@henry: add one more output @FutureBetCredit to show negative bet credit that may happen after the transfer
		- 20110123@Thien: fix the FutureBetCredit formula
		- 20111108@Lukas: Get more column syncCasino
		- 20120403@Lukas: Get more column DisableCasino
*/
SET NOCOUNT ON
DECLARE @currentDate datetime 
SELECT @currentDate = convert(varchar(10), CURRENT_TIMESTAMP, 120)
SELECT @IsAllowTotalBalance = isnull(@IsAllowTotalBalance, 0)

DECLARE @RoleID INT --nqminh - 19Feb09

IF (@IsAllowTotalBalance = 0)
    select   
	     @RoleID = customer.roleid, --nqminh - 19Feb09
	     @LastLogin = customer.lastlogged,
	     @Username = customer.username,  
		 @syncCasino = ci.syncCasino,
		 @DisableCasino = ci.DisableCasino,
	     @GivenCredit = ci.credit,
	     @CashBalance = isnull(b.CashBalance,0)
    from   
	    customer with (NOLOCK)  
	    INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.CustID  
	    LEFT JOIN 
		    (	SELECT custid, isnull(sum( case when b.bettype < 19001 and b.winlostdate < @currentDate then b.winlost-b.actual_stake+playercomm
											    when b.bettype > 19000 then b.winlost-b.actual_stake +playercomm
											    else 0 end ), 0) as CashBalance 
			    FROM bettrans as b with (NOLOCK) 
			    WHERE custid = @CustID and ruben  =1 
			    GROUP BY custid 
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @CustID  
ELSE
    select   
	     @RoleID = customer.roleid, --nqminh - 19Feb09
	     @LastLogin = customer.lastlogged,
	     @Username = customer.username, 
		 @syncCasino = ci.syncCasino, 
		 @DisableCasino = ci.DisableCasino,
	     @GivenCredit = ci.credit,
	     @CashBalance = isnull(b.CashBalance,0)
    from   
	    customer with (NOLOCK)  
	    INNER JOIN CustInfo as ci with (NOLOCK) on Customer.CustID = ci.CustID  
	    LEFT JOIN 
		    (	SELECT custid, isnull(sum( case when b.bettype < 19001 then b.winlost-b.actual_stake+playercomm
											    when b.bettype > 19000 then b.winlost-b.actual_stake +playercomm
											    else 0 end ), 0) as CashBalance 
			    FROM bettrans as b with (NOLOCK) 
			    WHERE custid = @CustID and ruben  =1 
			    GROUP BY custid 
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @CustID  

select @BetCredit = @GivenCredit + @CashBalance

SELECT @Oustanding = SUM(bettrans.actual_stake) FROM bettrans WITH (NOLOCK)
WHERE bettrans.bettype < 19001 AND
	  bettrans.ruben=0 AND
	  bettrans.custid=@custid
GROUP BY bettrans.custid

--Start - nqminh - 19Feb09	
IF (@RoleId = 1)
BEGIN
	DECLARE @TotalCash money
	SELECT @TotalCash = SUM(case when ruben=1 then winlost-actual_stake+playercomm else 0 end),
		@AmtTransferred = SUM(case when ruben=1 and winlostdate = @currentDate and bettype = 21004 then winlost - actual_stake else 0 end)
	FROM bettrans 
	WHERE custid = @CustID

	SELECT @BetCredit = @GivenCredit + @TotalCash - @Oustanding
END
--End - nqminh - 19Feb09	

select @Balance = @CashBalance

select @MaxTransDate = MAX(transdate) FROM bettrans WITH (NOLOCK) WHERE custid=@custid

if @CashBalance > 0 
	set @FutureBetCredit = @GivenCredit - @Oustanding + @TotalCash - @CashBalance
else
	set @FutureBetCredit = 0

GO
GRANT EXECUTE ON [dbo].[Age_Transfer_SelMemberInfo_Yesterday] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Transfer_SelMemberInfo_Yesterday] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Transfer_SelMemberInfo_Yesterday] TO [vnteam]