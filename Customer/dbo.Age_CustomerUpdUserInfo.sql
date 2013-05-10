ALTER PROCEDURE [dbo].[Age_CustomerUpdUserInfo]
    @custid INT , --customer to be updated
    @firstname NVARCHAR(50) ,
    @lastname NVARCHAR(50) ,
    @phone NVARCHAR(50) ,
    @mobilephone NVARCHAR(50) ,
    @email NVARCHAR(50) ,
    @fax NVARCHAR(50) ,
    @discasino BIT = 0 ,
    @IP AS VARCHAR(15) = '' ,
    @userid INT , --updater Id	
    @subaccid INT = 0 , --Sub-AccountID
    @language VARCHAR(2) = 'E' ,
    @errorcode INT = 0 OUTPUT ,
    @errormsg NVARCHAR(200) = '' OUTPUT
AS /*
Created: 20090211@nqminh
Task : Select customer information
DB: DBTXN/bodb02
Original:

Revisions:
    - 20090318@Hanh: add Korean language
	- 20090729@Phuc: Write log subaccname instead of subaccid.
	- 20090818@Phuc: check page access and check upline closed first(call Age_CustSubCheckPageAccess)
	- 20090917@Phuc: write log into DBLOG.
	- 20091008@Kiwi: Remove WriteLog_UserLog
	- 20091125@Terry: Check disable casino
	- 20100108@Lewin: Change SP format
	- 20100917@Kiwi: Correct "convert wrong datatype when writing log"
	- 20101021@Henry: Record execution time
	- 20110606@Amy: Write log old values
	- 20110907@Sophia: Change Linked Server from DB052 to DB053	
	- 20121128@Elodie: Get an error message from f_Get_MsgNameByMsgID function by language
	- 20130311@Dan: Change linked server DB053 to DBAGE; Write more log on DBTXN server in case of DBLOG server failure
Param's Explanation:
• @custid: custid that need to be viewed.   
*/

    SET NOCOUNT ON
	declare @startRun datetime
	declare @endRun datetime
	declare @duration int
	set @startRun = getdate()
	
	Declare @Old_firstname NVARCHAR(50) ,
			@Old_lastname NVARCHAR(50) ,
			@Old_phone NVARCHAR(50) ,
			@Old_mobilephone NVARCHAR(50) ,
			@Old_email NVARCHAR(50) ,
			@Old_fax NVARCHAR(50)

--Check disable user
    EXEC DBAGE.bodb02.dbo.Acc_CustomerSelCheckEnable @custid = @custid,
        @ErrCode = @errorcode OUTPUT, @ErrMsg = @errormsg OUTPUT
    IF @errorcode <> 0 
        RETURN
--end

	SELECT @Old_firstname = firstname,
    @Old_lastname =lastname,
    @Old_phone = phone,
    @Old_mobilephone = mobilephone,
    @Old_email = email,
    @Old_fax = fax 
    FROM Customer WITH (NOLOCK) WHERE custid = @custid    

    IF @disCasino = 1 
        BEGIN	
            SELECT  @errormsg = CASE @Language
                                  WHEN 'E' THEN 'This USER INFO function is temporarily unavailable, please update later.'
                                  ELSE [dbo].[f_Get_MsgNamebyMsgID](40005,@Language)
                                END ,
                    @errorcode = 100
            RETURN
        END

IF @Old_firstname = @firstname AND
    @Old_lastname = @lastname AND
    @Old_phone = @phone AND
    @Old_mobilephone = @mobilephone AND
    @Old_email = @email AND
    @Old_fax = @fax 
    RETURN

--Do update
    UPDATE  Customer WITH (ROWLOCK)
    SET     firstname = @firstname ,
            lastname = @lastname ,
            phone = @phone ,
            mobilephone = @mobilephone ,
            email = @email ,
            fax = @fax
    WHERE   custid = @custid

--Error return
    IF ( @@error <> 0 ) 
        BEGIN
            SELECT  @ErrorMsg = CASE @language
                                  WHEN 'E' THEN 'Update process is unsuccessful.'
                                  ELSE [dbo].[f_Get_MsgNamebyMsgID](90001,@Language)                                  
                                END ,
                    @ErrorCode = 102
            RETURN
        END


------------------------
--Write log file
    DECLARE @LogSPData NVARCHAR(4000)
    DECLARE @TrackingValue2 NVARCHAR(4000)

    SELECT  @LogSPData = '<Age_CustomerUpdUserInfo CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'FirstName="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@firstname AS NVARCHAR(50)),SPACE(1))) + '" ' 
						+ 'LastName="'+ dbo.f_EncodeXMLValue(COALESCE(CAST(@lastname AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Phone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@phone AS NVARCHAR(50)), SPACE(1))) + '" ' 
						+ 'MobilePhone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@mobilephone AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Email="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@email AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Fax="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@fax AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'IP="' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" ' 
						+ 'SubAccName="' + COALESCE(CAST(dbo.f_GetSubUsername(@SubAccID) AS VARCHAR(30)), SPACE(1)) + '" ' 
						+ 'UserID="' + COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)), SPACE(1)) + '" '
						+ 'ErrCode="' + COALESCE(CAST(@ErrorCode AS VARCHAR(50)), SPACE(1)) + '" ' 
						+ 'ErrMsg="' + COALESCE(CAST(@ErrorMsg AS VARCHAR(2000)), SPACE(1)) + '" />'

SELECT  @TrackingValue2 = '<Age_CustomerUpdUserInfo CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'FirstName="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_firstname AS NVARCHAR(50)),SPACE(1))) + '" ' 
						+ 'LastName="'+ dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_lastname AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Phone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_phone AS NVARCHAR(50)), SPACE(1))) + '" ' 
						+ 'MobilePhone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_mobilephone AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Email="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_email AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Fax="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_fax AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'IP="' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" ' 
						+ 'SubAccName="' + COALESCE(CAST(dbo.f_GetSubUsername(@SubAccID) AS VARCHAR(30)), SPACE(1)) + '" ' 
						+ 'UserID="' + COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)), SPACE(1)) + '" '
						+ 'ErrCode="' + COALESCE(CAST(@ErrorCode AS VARCHAR(50)), SPACE(1)) + '" ' 
						+ 'ErrMsg="' + COALESCE(CAST(@ErrorMsg AS VARCHAR(2000)), SPACE(1)) + '" />'

set @endRun = getdate()
set @duration  = datediff (millisecond,@startRun,@endRun)

BEGIN TRY
	/*609	Age_CustomerUpdUserInfo	Update downline's info*/
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID, 
		@ActionID = 609, 
		@TrackingValue = @LogSPData	,
		@TrackingValue2 = @TrackingValue2 ,
		@duration = @duration
END TRY
BEGIN CATCH
    SELECT  @LogSPData = '<Age_CustomerUpdUserInfo CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'FirstName="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@firstname AS NVARCHAR(50)),SPACE(1))) + '" ' 
						+ 'LastName="'+ dbo.f_EncodeXMLValue(COALESCE(CAST(@lastname AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Phone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@phone AS NVARCHAR(50)), SPACE(1))) + '" ' 
						+ 'MobilePhone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@mobilephone AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Email="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@email AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Fax="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@fax AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'IP="' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" ' 
						+ 'SubAccName="' + COALESCE(CAST(dbo.f_GetSubUsername(@SubAccID) AS VARCHAR(30)), SPACE(1)) + '" ' 
						+ 'UserID="' + COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)), SPACE(1)) + '" '
						+ 'ErrCode="' + COALESCE(CAST(ERROR_NUMBER() AS VARCHAR(50)), SPACE(1)) + '" ' 
						+ 'ErrMsg="' + COALESCE(CAST(ERROR_MESSAGE() AS VARCHAR(2000)), SPACE(1)) + '" />'

	SELECT  @TrackingValue2 = '<Age_CustomerUpdUserInfo CustID="' + COALESCE(CAST(@CustID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'FirstName="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_firstname AS NVARCHAR(50)),SPACE(1))) + '" ' 
						+ 'LastName="'+ dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_lastname AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Phone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_phone AS NVARCHAR(50)), SPACE(1))) + '" ' 
						+ 'MobilePhone="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_mobilephone AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Email="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_email AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'Fax="' + dbo.f_EncodeXMLValue(COALESCE(CAST(@Old_fax AS NVARCHAR(50)), SPACE(1))) + '" '
						+ 'IP="' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + '" ' 
						+ 'SubAccName="' + COALESCE(CAST(dbo.f_GetSubUsername(@SubAccID) AS VARCHAR(30)), SPACE(1)) + '" ' 
						+ 'UserID="' + COALESCE(CAST(@UserID AS VARCHAR(50)), SPACE(1)) + '" '
						+ 'Language="' + COALESCE(CAST(@Language AS VARCHAR(2)), SPACE(1)) + '" '
						+ 'ErrCode="' + COALESCE(CAST(ERROR_NUMBER() AS VARCHAR(50)), SPACE(1)) + '" ' 
						+ 'ErrMsg="' + COALESCE(CAST(ERROR_MESSAGE() AS VARCHAR(2000)), SPACE(1)) + '" />'

	/*609	Age_CustomerUpdUserInfo	Update downline's info*/
	EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
		@UserID = @UserID,
		@CustID = @CustID, 
		@ActionID = 609, 
		@TrackingValue = @LogSPData	,
		@TrackingValue2 = @TrackingValue2 ,
		@duration = @duration
END CATCH
GO
GRANT EXECUTE ON [dbo].[Age_CustomerUpdUserInfo] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_CustomerUpdUserInfo] TO [vnteam]