/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp,wsv_alpv" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_WhiteLabelListSel]
	@CustID 		INT --recommend/ mrecommend/ srecommend
AS
/*
    Created: 
    Task : 
    DB: DBAGE/bodb02
   
	Revisions:
        - 20240826@Danny: White Label winloss report - [Redmine: #209633]
	-- super
		EXEC Age_WhiteLabelListSel 
				@CustID 		= 4
			
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @RoleID TINYINT
	SELECT @RoleID = RoleID FROM bodb02.dbo.CustInfo WITH(NOLOCK) WHERE CustID = @CustID

	SELECT wl.CustID, WhiteLabel
	FROM WhiteLabelInfo  wl WITH(NOLOCK)
	INNER JOIN custInfo ci WITH(NOLOCK) ON wl.CustID = ci.custid
	WHERE (ci.srecommend = @CustID AND @RoleID = 4 )
	OR (ci.mrecommend = @CustID AND @RoleID = 3 )
	OR (ci.recommend = @CustID AND @RoleID = 2 )
	OR wl.CustID = @CustID

	SET NOCOUNT OFF;
END
GO