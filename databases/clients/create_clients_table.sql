USE clients
GO
CREATE TABLE [dbo].[casinos](
	[uuid] [uniqueidentifier] NULL,
	[index_key] [int] IDENTITY(1,1) NOT NULL,
	[reference_key] [nvarchar](25) NULL
	[insert_date] [datetime2](7) NOT NULL,
	[update_date] [datetime2](7) NOT NULL,
	[update_by] [nvarchar](100) NOT NULL,
	[change_log] [nvarchar](255) NULL,
	[casino_name] [nvarchar](100) NOT NULL,
	[legal_title] [nvarchar](100) NULL,
	[casino_short] [nvarchar](100) NULL,
	[casino_abbreviation] [nvarchar](50) NULL,
	[logo_path] [nvarchar](250) NULL,
	[casino_priority] [tinyint] NULL,
	[given_house_average] [int] NULL,
	[calculated_house_average] [int] NULL,
	[total_number_of_machines] [int] NULL,
	[sales] [nvarchar](50) NULL,
	[tribe_name] [nvarchar](100) NULL,
	[tribe_short] [nvarchar](100) NULL,
	[back_end_os] [nvarchar](100) NULL,
	[bill_validator] [nvarchar](100) NULL,
	[printer] [nvarchar](100) NULL,
	[phone] [nvarchar](20) NULL,
	[state] [nvarchar](100) NULL,
	[address] [nvarchar](100) NULL,
	[city] [nvarchar](100) NULL,
	[state_abbreviation] [nvarchar](50) NULL,
	[zip] [int] NULL,
	[longitude] [float] NULL,
	[latitude] [float] NULL,
	[general_manager_name] [nvarchar](75) NULL,
	[general_manager_email] [nvarchar](75) NULL,
	[slot_director_name] [nvarchar](75) NULL,
	[slot_director_email] [nvarchar](75) NULL,
	[accounting_name] [nvarchar](75) NULL,
	[accounting_email] [nvarchar](75) NULL,
	[last_report] [nvarchar](75) NULL,
	[casino_referal] [nvarchar](50) NULL,
	[dgs_referal] [nvarchar](50) NULL,
	[executed_on] [date] NULL,
	[expiration] [date] NULL,
	[master] [nvarchar](50) NULL,
	[compliance_id] [nvarchar](50) NULL,
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[casino_new_06_12_2025] ADD  DEFAULT (newid()) FOR [uuid]
GO
ALTER TABLE [dbo].[casino_new_06_12_2025] ADD  DEFAULT (getdate()) FOR [insert_date]
GO
ALTER TABLE [dbo].[casino_new_06_12_2025] ADD  DEFAULT (getdate()) FOR [update_date]
GO


  
USE clients
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[trg_insert_casino]
ON [dbo].[casino_new_06_12_2025]
AFTER INSERT
AS
BEGIN
    -- Ensure UUID is generated for rows where it is NULL
    UPDATE cas
    SET cas.uuid = NEWID()
    FROM casino_new_06_12_2025 cas
    INNER JOIN inserted i ON cas.index_key = i.index_key
    WHERE cas.uuid IS NULL;

    -- Populate reference_key and change_log for newly inserted rows
    UPDATE cas
    SET
        cas.reference_key = 'CT-' + RIGHT('000' + CAST(cas.index_key AS VARCHAR), 3),
        cas.change_log = 'Created on ' + CONVERT(NVARCHAR, GETDATE(), 120)
    FROM casino_new_06_12_2025 cas
    INNER JOIN inserted i ON cas.index_key = i.index_key;

    -- Insert into activity_logs only if UUID is not NULL
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name)
    SELECT 
        i.uuid AS log_id, -- Use the UUID column
        'Created on ' + CONVERT(NVARCHAR, GETDATE(), 120) AS change_log,
        'System' AS update_by, -- Replace with appropriate value
        'casino' AS table_name
    FROM inserted i
    WHERE i.uuid IS NOT NULL; -- Ensure UUID is not NULL
END
GO
ALTER TABLE [dbo].[casino_new_06_12_2025] ENABLE TRIGGER [trg_insert_casino]
GO


USE clients
GO
CREATE TRIGGER [dbo].[trg_format_phone]
ON [dbo].[casino_new_06_12_2025]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[casino_new_06_12_2025]
    SET [phone] = '(' + SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 1, 3) + ') ' +
                  SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 4, 3) + '-' +
                  SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 7, 4)
    WHERE [uuid] IN (SELECT [uuid] FROM inserted);
END
