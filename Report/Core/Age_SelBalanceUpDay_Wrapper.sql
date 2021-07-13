/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet,bodbExtAccNet,bodbDownlineNet,bodbDownlineNetView" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE Age_SelBalanceUpDay_Wrapper
(
	@MovebetDay SMALLDATETIME = '' OUTPUT,
	@BalanceUpDay SMALLDATETIME = '' OUTPUT
)
AS
/*
	Created by Sol
	Date: 20210713
	DB: DBAGE.bodb02
	Task: Core SP - wrapper Age_SelBalanceUpDay to get MB from output param

	Revisions:
		- 20210505@Sol: NAP - Alpha - Allow more time for transfer - get MB date from output - [Redmine: #149927]
*/
BEGIN

	DECLARE @tblMoveBetBalanceUp AS TABLE (BalanceUpDay SMALLDATETIME, MoveBetDay SMALLDATETIME)

	INSERT INTO @tblMoveBetBalanceUp(BalanceUpDay,MoveBetDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @BalanceUpDay = BalanceUpDay, @MovebetDay = MoveBetDay FROM @tblMoveBetBalanceUp

END

GO