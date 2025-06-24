USE clients
GO
CREATE TABLE dbo.order_detail(
    uuid uniqueidentifier NULL,
    index_key int IDENTITY(1,1) NOT NULL,
    reference_key nvarchar(25) NULL,
    insert_date datetime NULL,
    update_date datetime NULL,
    update_by varchar(50) NULL,
    change_log nvarchar(max) NULL,
    item_type NVARCHAR(50) NULL,
    sales_order_key varchar(25) NULL,
    slot_master_key varchar(25) NULL,
    vendor nvarchar(50) NULL,
    cabinet nvarchar(50) NULL,
    theme nvarchar(50) NULL,
    other nvarchar(100) NULL,
    price int NULL,
    quantity int NULL
)
GO
ALTER TABLE dbo.order_detail ADD  DEFAULT (newid()) FOR uuid
GO
ALTER TABLE dbo.order_detail ADD  DEFAULT (getdate()) FOR insert_date
GO
ALTER TABLE dbo.order_detail ADD  DEFAULT (getdate()) FOR update_date
GO
CREATE TRIGGER dbo.trg_insert_order_detail
ON dbo.order_detail
AFTER INSERT
AS
BEGIN
    -- Update the UUID for rows where it is NULL
    UPDATE od
    SET od.uuid = NEWID()
    FROM order_detail od
    INNER JOIN inserted i ON od.index_key = i.index_key
    WHERE i.uuid IS NULL;

    -- Populate the reference_key field
    UPDATE od
    SET 
        od.reference_key = 'DT-' + RIGHT('0000000' + CAST(od.index_key AS VARCHAR), 7),
        od.change_log = 'Created on ' + CONVERT(NVARCHAR, GETDATE(), 120)
    FROM order_detail od
    INNER JOIN inserted i ON od.index_key = i.index_key;

    -- Log the initial values into activity_logs
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name)
    SELECT 
        COALESCE(i.uuid, NEWID()) AS log_id, -- Ensure log_id is never NULL
        JSON_QUERY((
            SELECT 
                i.* 
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS change_log,
        i.update_by AS update_by, -- Pass through the updated_by column
        'order_detail' AS table_name -- Hardcode the table name
    FROM inserted i;
END
GO
ALTER TABLE dbo.order_detail ENABLE TRIGGER trg_insert_order_detail
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER dbo.trg_update_order_detail
ON dbo.order_detail
AFTER UPDATE
AS
BEGIN
    -- Log the changes into activity_logs
    INSERT INTO logs.dbo.activity_logs (log_id, change_log, update_by, table_name)
    SELECT 
        COALESCE(i.uuid, NEWID()) AS log_id, -- Ensure log_id is never NULL
        JSON_QUERY(( 
            SELECT 
                (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS before_values,
                (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS after_values
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS change_log, -- Log before and after values as JSON
        i.update_by AS update_by, -- Pass through the updated_by column
        'order_detail' AS table_name -- Hardcode the table name
    FROM inserted i
    INNER JOIN deleted d ON i.index_key = d.index_key; -- Match updated rows

    -- Update the change_log in order_detail with the most recent log reference
    UPDATE od
    SET od.change_log = 'Updated on ' + CONVERT(NVARCHAR, GETDATE(), 120) + ' Log key: (' + al.reference_key + ')'
    FROM order_detail od
    INNER JOIN inserted i ON od.index_key = i.index_key
    INNER JOIN (
        SELECT log_id, reference_key, ROW_NUMBER() OVER (PARTITION BY log_id ORDER BY timestamp DESC) AS row_num
        FROM logs.dbo.activity_logs
    ) al ON al.log_id = i.uuid AND al.row_num = 1; -- Use the most recent log entry
END
GO
ALTER TABLE dbo.order_detail ENABLE TRIGGER trg_update_order_detail
GO
