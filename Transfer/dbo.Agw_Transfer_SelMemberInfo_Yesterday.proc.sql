ALTER  PROCEDURE [dbo].[Agw_Transfer_SelMemberInfo_Yesterday]
	@parentCustID int,
	@username varchar(20), 
	@RoleID tinyint, 
	@Language varchar(2)= 'E',	
	@IsAllowTotalBalance bit = 0, --
	@ChildCustID int=0 OUTPUT,
	@CashBalance money=0 OUTPUT,
	@Balance money=0 OUTPUT,
	@Oustanding money=0 OUTPUT,
	@GivenCredit money=0 OUTPUT,
	@BetCredit money=0 OUTPUT,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
SET NOCOUNT ON

/*
Task : Select transfer information
DB: DB05/DB052.bodb02
Original: 

Revisions:
		- 20100105@Lee: Remove getting currency
		- 20110513@Johnson: Apply new arrange bettype
		- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
*/


set @ChildCustID = isnull((select custid from customer with (NOLOCK) where username=@username),-1)
if @ChildCustID<>-1
	set @ChildCustID = isnull((select custid from customer as c with (NOLOCK) 
						where @parentCustID = case @RoleID when 4 then c.srecommend when 3 then c.mrecommend when 2 then c.recommend else -1 end
							AND c.roleid = @RoleID-1
							and @ChildCustID=c.custid),-1)
if @ChildCustID=-1
begin 
	IF @Language = 'E'
		Select @ErrMsg = 'Customer does not exist.' 	
	ELSE		
		EXEC @ErrMsg = DBLOG.bodb_CustomerLog.[dbo].[f_Get_MsgNamebyMsgID] '40014',@Language
	SELECT @ErrCode = 102
	select @ErrMsg
	return
end

-- Calculate paras
DECLARE @currentDate datetime 
SELECT @currentDate = convert(varchar(10), CURRENT_TIMESTAMP, 120)

-- UserName is Master Level
if @RoleID=4
Begin
	select 	@Balance = isnull(sum(case when custid=mrecommend then winlost-actual_stake else mwinlost+acomm-comm end), 0)
					+ isnull(sum(case when custid<>mrecommend and custid <> recommend and custid<>srecommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) 
					+ IsNull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0) 
					- IsNull(sum(case when bettype <= 19000 and winlostdate >= @currentDate and ruben =1 then winlost-actual_stake + mwinlost + acomm + awinlost else 0 end), 0)
	from bettrans with(nolock)
	where mrecommend=@ChildCustID
	group by mrecommend 
	return
End

-- UserName is Agent Level
if @RoleID=3
Begin	
	select 	@Balance = isnull(sum(case when custid=recommend then winlost-actual_stake else awinlost+comm-playercomm end), 0)  	
					+ isnull(sum(case when custid<>recommend and ruben=1 then winlost-actual_stake+playercomm else 0 end), 0) 
					- isnull(sum(case when bettype <= 19000 and winlostdate >= @currentDate and ruben =1 then awinlost+comm + winlost-actual_stake else 0 end ), 0)
	from bettrans with(nolock)
	where recommend=@ChildCustID
	group by recommend
	return
End

-- UserName is Member
If (@IsAllowTotalBalance = 0)
    select 
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
			    WHERE custid = @ChildCustID and ruben  =1 
			    GROUP BY custid 
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @ChildCustID 
Else
    select 
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
			    WHERE custid = @ChildCustID and ruben  =1 
			    GROUP BY custid 
		    ) as b ON customer.custid=b.custid  
    where  
	    customer.custid= @ChildCustID


select @BetCredit = @GivenCredit + @CashBalance

SELECT @Oustanding = SUM(bettrans.actual_stake) FROM bettrans WITH (NOLOCK)
WHERE 
	bettrans.bettype<= 19000 AND
	bettrans.ruben=0 AND
	bettrans.custid=@ChildCustID	
GROUP BY
	bettrans.custid	

select @Balance = @CashBalance

GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelMemberInfo_Yesterday] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Agw_Transfer_SelMemberInfo_Yesterday] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Agw_Transfer_SelMemberInfo_Yesterday] TO [vnteam]