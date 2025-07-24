USE clients
GO

-- Create the table with `uuid` allowing NULL
CREATE TABLE casinos (
    uuid UNIQUEIDENTIFIER NULL DEFAULT NEWID(), -- Allow NULL and auto-generate UUID not if provided
    index_key INT IDENTITY(1,1) NOT NULL, -- Auto-incrementing identity column
    reference_key NVARCHAR(25) NULL,
    insert_date DATETIME NULL DEFAULT GETDATE(),
    update_date DATETIME NULL DEFAULT GETDATE(),
    update_by NVARCHAR(50) NULL,
    change_log NVARCHAR(255) NULL,
    casino_name NVARCHAR(100) NOT NULL,
    legal_title NVARCHAR(100) NULL,
    casino_short NVARCHAR(100) NULL,
    casino_abbreviation NVARCHAR(50) NULL,
    tribe_id NVARCHAR(25) NULL,
    logo_path NVARCHAR(250) NULL,
    casino_priority TINYINT NULL,
    main_house_average INT NULL,
    smoking_adw INT NULL,
    high_limit_adw INT NULL,
    calculated_house_average INT NULL,
    total_number_of_machines INT NULL,
    os_id NVARCHAR(25) NULL,
    bv_id NVARCHAR(25) NULL,
    printer_id NVARCHAR(25) NULL,
    state_id NVARCHAR(25) NULL,
    address NVARCHAR(100) NULL,
    city NVARCHAR(100) NULL,
    zip INT NULL,
    longitude FLOAT NULL,
    latitude FLOAT NULL,
    phone NVARCHAR(20) NULL,
    sales NVARCHAR(50) NULL,
    available_vendors NVARCHAR(MAX) NULL,
    goal INT NULL,
    route_week INT NULL,
    last_report DATE NULL,
    general_manager_name NVARCHAR(75) NULL,
    general_manager_email NVARCHAR(75) NULL,
    slot_director_name NVARCHAR(75) NULL,
    slot_director_email NVARCHAR(75) NULL,
    accounting_name NVARCHAR(75) NULL,
    accounting_email NVARCHAR(75) NULL,
    casino_referal NVARCHAR(50) NULL,
    dgs_referal NVARCHAR(50) NULL,
    licensed BINARY NOT NULL DEFAULT 0,
    signed_master_agreement BINARY NOT NULL DEFAULT 0,
    executed_on DATE NULL,
    expiration DATE NULL,
    agreement_type NVARCHAR(50) NULL,
    split DECIMAL(2,2) NULL,
    cap INT NULL,
    fee INT NULL,
    loss_passed BINARY NOT NULL DEFAULT 0,
    minimum INT NULL,
    compliance_id NVARCHAR(25) NULL
)

USE clients
GO
CREATE TRIGGER [trg_insert_casino]
ON casinos
AFTER INSERT
AS
BEGIN
    -- Generate UUID for rows where it is NULL
    UPDATE ca
    SET ca.uuid = NEWID()
    FROM casinos ca
    INNER JOIN inserted i ON ca.index_key = i.index_key
    WHERE ca.uuid IS NULL;

    -- Populate reference_key and change_log for newly inserted rows
    UPDATE ca
    SET
        ca.reference_key = 'CT-' + RIGHT('00000' + CAST(ca.index_key AS VARCHAR), 5),
        ca.change_log = 'Created on ' + CONVERT(NVARCHAR, GETDATE(), 120)
    FROM casinos ca
    INNER JOIN inserted i ON ca.index_key = i.index_key;

    -- Log the initial values into activity_logs
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name)
    SELECT 
        i.uuid AS log_id, -- Use the UUID column
        JSON_QUERY((SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS change_log,
        i.update_by AS update_by, -- Pass through the updated_by column
        'casinos' AS table_name -- Hardcode the table name
    FROM inserted i
    WHERE i.uuid IS NOT NULL; -- Ensure UUID is not NULL
END
GO

USE clients
GO
CREATE TRIGGER [dbo].[trg_update_casino]
ON [dbo].[casinos]
AFTER UPDATE
AS
BEGIN
    -- Step 1: Update the `update_date` for all updated rows
    UPDATE ca
    SET ca.update_date = GETDATE()
    FROM casinos ca
    INNER JOIN inserted i ON ca.uuid = i.uuid;

    -- Step 2: Log the changes into `activity_logs`
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name, timestamp)
    SELECT 
        COALESCE(i.uuid, NEWID()) AS log_id, -- Ensure log_id is never NULL
        JSON_QUERY(( 
            SELECT 
                (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS before_values,
                (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS after_values
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS change_log, -- Log before and after values as JcaN
        i.update_by AS update_by, -- Pass through the updated_by column
        'casinos' AS table_name, -- Hardcode the table name
        GETDATE() AS timestamp -- Add the current timestamp
    FROM inserted i
    INNER JOIN deleted d ON i.uuid = d.uuid; -- Match updated rows

    -- Step 3: Update the `change_log` in `sales_order` with the most recent log reference
    UPDATE ca
    SET ca.change_log = 'Updated on ' + CONVERT(NVARCHAR, GETDATE(), 120) + ' Log key: (' + al.reference_key + ')'
    FROM casinos ca
    INNER JOIN inserted i ON ca.uuid = i.uuid
    INNER JOIN (
        SELECT log_id, reference_key, ROW_NUMBER() OVER (PARTITION BY log_id ORDER BY timestamp DESC) AS row_num
        FROM logs.dbo.activity_logs
    ) al ON al.log_id = i.uuid AND al.row_num = 1; -- Use the most recent log encay
END
GO

USE clients
GO
CREATE TRIGGER [dbo].[trg_format_phone]
ON [dbo].[casinos]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[casinos]
    SET [phone] = '(' + SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 1, 3) + ') ' +
                    SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 4, 3) + '-' +
                    SUBSTRING(REPLACE(REPLACE(REPLACE([phone], '-', ''), ' ', ''), '(', ''), 7, 4)
    WHERE [uuid] IN (SELECT [uuid] FROM inserted);
END
