ALTER PROCEDURE [dbo].[Dot_Casino_Customer_GetTransferOption]
	@CustId int,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: 
Task : Get customer' transfer options code by ibc custid
DB: DB02.BODB02
Original: 

Revisions:
	- 20100414@Kiwi: Change to get transferoption from CustSuper/CustMaster/CustAgent
	
Param's Explanation:
*/
DECLARE @Code tinyint
BEGIN
	
	BEGIN TRY
		SELECT @ErrCode = 0,@ErrMsg=''

		DECLARE @RoleID TINYINT 
		SELECT @RoleID = RoleID FROM custinfo WITH (NOLOCK) WHERE custid = @CustId

		IF (@RoleID = 4)
		BEGIN 
			SELECT @Code = ISNULL(TransferOption,0)
			FROM CustSuper  WITH (NOLOCK) 
			WHERE custid = @CustId
		END
		ELSE IF (@RoleID = 3)
		BEGIN 
			SELECT @Code = ISNULL(TransferOption,0)
			FROM CustMaster  WITH (NOLOCK) 
			WHERE custid = @CustId
		END
		ELSE IF (@RoleID = 2)
		BEGIN 
			SELECT @Code = ISNULL(TransferOption,0)
			FROM CustAgent  WITH (NOLOCK) 
			WHERE custid = @CustId
		END

		IF (@Code IS NULL)
			BEGIN
				SELECT @Code = 0
			END
		
		SELECT @Code AS transferoption
		RETURN
	END TRY

	BEGIN CATCH
		SELECT @ErrMsg ='ErrMsg : ' + ERROR_MESSAGE() + ' ErrLine :' + ERROR_LINE(), @ErrCode = ERROR_NUMBER()
		RETURN
	END CATCH	

END

GO
GRANT EXECUTE ON [dbo].[Dot_Casino_Customer_GetTransferOption] TO [Dot_Casino]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_Customer_GetTransferOption] TO [vnteam]
