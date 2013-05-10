IF EXISTS (SELECT * FROM sysobjects WHERE type = 'TR' AND name = 'Trigger_Name')
	BEGIN
		DROP  Trigger Trigger_Name
	END
GO

CREATE Trigger Trigger_Name ON Table_Name 
FOR INSERT, UPDATE, DELETE AS 

	/*insert into */

GO

