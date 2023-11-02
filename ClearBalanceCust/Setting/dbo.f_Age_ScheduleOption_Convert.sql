/*<info serverAlias="DBCUST-CustDB,DBAGE-bodb02,DBCTG-bodb02" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.f_Age_ScheduleOption_Convert(@ScheduleOption TINYINT) 
RETURNS VARCHAR(1000)
BEGIN
/*
	Created:20231027@Bobby
	Task: 195135 - AutoJob transfer - schedule option
	DB: DBAGE-bodb02

	Revisions:
		- 20231027@Bobby: AutoJob transfer - schedule option [RedmineID: #195135]

*/
	DECLARE @strDayWeek VARCHAR(4000)='';

	SELECT @strDayWeek = STRING_AGG(DayWeek, ',')
	FROM (
		SELECT DayWeek, DayNameShort, DayNameLong, BitCheck 
		FROM (
			VALUES 
				(1, 'Sun', 'Sunday',	@ScheduleOption & POWER(2, 1)),
				(2, 'Mon', 'Monday',	@ScheduleOption & POWER(2, 2)),
				(3, 'Tue', 'Tuesday',	@ScheduleOption & POWER(2, 3)),
				(4, 'Wed', 'Wednesday', @ScheduleOption & POWER(2, 4)),
				(5, 'Thu', 'Thursday',	@ScheduleOption & POWER(2, 5)),
				(6, 'Fri', 'Friday',	@ScheduleOption & POWER(2, 6)),
				(7, 'Sat', 'Saturday',	@ScheduleOption & POWER(2, 7))
		) AS t (DayWeek, DayNameShort, DayNameLong, BitCheck)
		WHERE BitCheck > 0
	)
	AS ck;

	RETURN ISNULL(@strDayWeek, '');
END
GO