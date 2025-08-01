USE clients
GO

CREATE TABLE projects(
    uuid UNIQUEIDENTIFIER NULL DEFAULT NEWID(), -- Allow NULL and auto-generate UUID prt if provided
    index_key INT IDENTITY(1,1) NOT NULL, -- Auto-incrementing identity column
    reference_key NVARCHAR(25) NULL,
    insert_date DATETIME NULL DEFAULT GETDATE(),
    update_date DATETIME NULL DEFAULT GETDATE(),
    update_by VARCHAR(50) NULL,
    change_log VARCHAR(255) NULL,
    casipr_id NVARCHAR(25) NULL,
    project_type NVARCHAR(25) NULL,
    proposal_status NVARCHAR(25) NULL,
    submitted BIT NOT NULL DEFAULT 0,
    date_submitted DATE NULL,
    date_follow_up DATE NULL,
    project_status NVARCHAR(25) NULL,
    project_date DATE NULL,
    project_number INT NULL,
    filepath NVARCHAR(1000) NULL,
    note NVARCHAR(MAX) NULL
)

USE clients
GO
CREATE TRIGGER [trg_insert_prte]
ON projects
AFTER INSERT
AS
BEGIN
    -- Generate UUID for rows where it is NULL
    UPDATE pr
    SET pr.uuid = NEWID()
    FROM projects pr
    INNER JOIN inserted i ON pr.index_key = i.index_key
    WHERE pr.uuid IS NULL;

    -- Populate reference_key and change_log for newly inserted rows
    UPDATE pr
    SET
        pr.reference_key = 'PR-' + RIGHT('000000' + CAST(pr.index_key AS VARCHAR), 6),
        pr.change_log = 'Created on ' + CONVERT(NVARCHAR, GETDATE(), 120)
    FROM projects pr
    INNER JOIN inserted i ON pr.index_key = i.index_key;

    -- Log the initial values into activity_logs
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name)
    SELECT 
        i.uuid AS log_id, -- Use the UUID column
        JSON_QUERY((SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS change_log,
        COALESCE(i.update_by, 'System') AS update_by, -- Fallback to 'System' if update_by is NULL
        'projects' AS table_name -- Hardcode the table name
    FROM inserted i
    WHERE i.uuid IS NOT NULL; -- Ensure UUID is prt NULL
END
GO


USE clients
GO
CREATE TRIGGER [dbo].[trg_update_pret]
ON projects
AFTER UPDATE
AS
BEGIN
    -- Step 1: Update the `update_date` for all updated rows
    UPDATE pr
    SET pr.update_date = GETDATE()
    FROM projects pr
    INNER JOIN inserted i ON pr.uuid = i.uuid;

    -- Step 2: Log the changes into `activity_logs`
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name, timestamp)
    SELECT 
        COALESCE(i.uuid, NEWID()) AS log_id, -- Ensure log_id is never NULL
        JSON_QUERY(( 
            SELECT 
                (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS before_values,
                (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS after_values
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS change_log, -- Log before and after values as JSON
        COALESCE(i.update_by, 'System') AS update_by, -- Fallback to 'System' if update_by is NULL
        'projects' AS table_name, -- Hardcode the table name
        GETDATE() AS timestamp -- Add the current timestamp
    FROM inserted i
    INNER JOIN deleted d ON i.uuid = d.uuid; -- Match updated rows

    -- Step 3: Update the `change_log` in `projects` with the most recent log reference
    UPDATE pr
    SET pr.change_log = 'Updated on ' + CONVERT(NVARCHAR, GETDATE(), 120) + ' Log key: (' + al.reference_key + ')'
    FROM projects pr
    INNER JOIN inserted i ON pr.uuid = i.uuid
    INNER JOIN (
        SELECT log_id, reference_key, ROW_NUMBER() OVER (PARTITION BY log_id ORDER BY timestamp DESC) AS row_num
        FROM logs.dbo.activity_logs
    ) al ON al.log_id = i.uuid AND al.row_num = 1; -- Use the most recent log entry
END
GO
