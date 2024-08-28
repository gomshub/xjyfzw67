To log messages with timestamps indicating when rows are inserted into a temporary table and when they are purged and committed, you can use Oracle’s `DBMS_OUTPUT` package to print messages, and `SYSDATE` or `SYSTIMESTAMP` to capture the current date and time. Additionally, you can efficiently fetch and print the row count of purged rows.

Here’s how you can structure a PL/SQL procedure to accomplish this:

### 1. **Procedure Structure with Logging**

The following example shows a procedure that:
- Logs the timestamp when rows are inserted into the temporary table.
- Logs the timestamp when rows are purged (deleted) from the temporary table.
- Fetches and logs the count of rows purged from the temporary table.

### Example Procedure

```sql
CREATE OR REPLACE PROCEDURE Process_Temp_Table (
    p_start_date IN DATE,
    p_end_date   IN DATE,
    p_gtt_name   IN VARCHAR2
) IS
    v_rows_inserted   NUMBER;
    v_rows_purged     NUMBER;
BEGIN
    -- Log start of insert operation
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || '] Starting row insertion into ' || p_gtt_name);

    -- Insert data into the specified GTT using the provided date range
    EXECUTE IMMEDIATE 'INSERT INTO ' || p_gtt_name || ' (id)
                       SELECT a.id
                       FROM Audit a
                       WHERE a.date_column >= :start_date
                       AND a.date_column < :end_date'
    USING p_start_date, p_end_date;

    -- Get the number of rows inserted
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_gtt_name INTO v_rows_inserted;
    
    -- Log the number of rows inserted
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || '] Rows inserted: ' || v_rows_inserted);

    -- Log start of purge operation
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || '] Starting row purge from ' || p_gtt_name);

    -- Delete from the main tables based on the IDs in the GTT
    EXECUTE IMMEDIATE 'DELETE FROM audit_link WHERE id IN (SELECT id FROM ' || p_gtt_name || ')';

    EXECUTE IMMEDIATE 'DELETE FROM Audit WHERE id IN (SELECT id FROM ' || p_gtt_name || ')';

    -- Get the number of rows purged
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_gtt_name INTO v_rows_purged;

    -- Log the number of rows purged
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || '] Rows purged: ' || v_rows_purged);

    -- Commit the transaction
    COMMIT;

    -- Log the commit
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF') || '] Transaction committed.');
END;
/
```

### 2. **Explanation of Key Components**

- **Timestamp Logging**: 
  - `SYSTIMESTAMP` is used for a high-precision timestamp, which includes fractional seconds.
  - `TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF')` formats the timestamp for logging.

- **Row Insertion**:
  - After inserting rows into the temporary table, the row count is retrieved using a `SELECT COUNT(*)` statement.

- **Row Purge**:
  - Similar to the insertion, after purging (deleting) the rows, the row count is fetched using another `SELECT COUNT(*)` statement.
  - The row counts are logged after each operation.

- **Logging**:
  - `DBMS_OUTPUT.PUT_LINE` is used to log messages, including timestamps and row counts.
  - Ensure that `DBMS_OUTPUT` is enabled in your SQL environment if you want to see the output in tools like SQL*Plus or SQL Developer.

### 3. **Running the Procedure**

When you run this procedure, it will print logs to the output with timestamps and row counts for the insertions, purges, and the final commit. Here’s an example call:

```sql
BEGIN
    Process_Temp_Table(
        p_start_date => TO_DATE('01-JAN-2020', 'DD-MON-YYYY'),
        p_end_date   => TO_DATE('01-FEB-2020', 'DD-MON-YYYY'),
        p_gtt_name   => 'temp_ids_to_delete_1'
    );
END;
/
```

### 4. **Enabling DBMS_OUTPUT**

To ensure that `DBMS_OUTPUT` works and you can see the output:

- In SQL*Plus:
  ```sql
  SET SERVEROUTPUT ON;
  ```

- In Oracle SQL Developer:
  - Go to `View > DBMS Output`.
  - Click on the green plus sign and select the connection.

### 5. **Performance Considerations**

- **Efficient Counting**: Counting rows after an insert or delete can be costly if the table is large. This is generally manageable with GTTs since they are typically smaller in size.
- **Logging Impact**: Frequent logging (especially with high precision timestamps) can impact performance. Consider the trade-off between the granularity of logging and the performance of the procedure.

### Summary

By combining dynamic SQL, `DBMS_OUTPUT`, and the use of `SYSTIMESTAMP`, this procedure effectively logs the progress and outcomes of inserting and purging rows in a global temporary table. It provides clear and timestamped logs that are useful for auditing and troubleshooting purposes.


=#=#=

Yes, you can create and use multiple Global Temporary Tables (GTTs) for each parallel session execution. However, this approach is generally unnecessary and can complicate your design. Typically, a single GTT with session-specific data handling is sufficient for parallel execution, as Oracle automatically isolates the data for each session.

### Scenario: Using Multiple GTTs for Parallel Sessions

If you have a specific reason to use multiple GTTs (perhaps to segregate data processing for different sessions manually), here's how you can do it:

1. **Create Multiple Global Temporary Tables**:
   - You would create several GTTs before executing your procedure in parallel sessions. Each GTT would be assigned to a specific session.

   ```sql
   CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete_1 (
       id NUMBER
   ) ON COMMIT DELETE ROWS;

   CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete_2 (
       id NUMBER
   ) ON COMMIT DELETE ROWS;

   CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete_3 (
       id NUMBER
   ) ON COMMIT DELETE ROWS;

   CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete_4 (
       id NUMBER
   ) ON COMMIT DELETE ROWS;

   CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete_5 (
       id NUMBER
   ) ON COMMIT DELETE ROWS;
   ```

2. **Modify the Procedure to Accept the GTT Name**:
   - Modify your procedure to accept the name of the GTT as a parameter, and use dynamic SQL to perform operations on the specified GTT.

   ```sql
   CREATE OR REPLACE PROCEDURE Delete_Old_Audit_And_Link(p_temp_table_name IN VARCHAR2) IS
   BEGIN
       -- Step 1: Insert the IDs that need to be deleted into the specified temporary table
       EXECUTE IMMEDIATE 'INSERT INTO ' || p_temp_table_name || ' (id)
                         SELECT a.id
                         FROM Audit a
                         JOIN audit_link al ON a.id = al.id
                         WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
                         AND al.object_type IN (3, 4, 5)';

       -- Step 2: Delete from the audit_link table using the specified temporary table
       EXECUTE IMMEDIATE 'DELETE FROM audit_link al
                          WHERE al.id IN (SELECT id FROM ' || p_temp_table_name || ')';

       -- Step 3: Delete from the Audit table using the specified temporary table
       EXECUTE IMMEDIATE 'DELETE FROM Audit a
                          WHERE a.id IN (SELECT id FROM ' || p_temp_table_name || ')';

       -- Commit the transaction
       COMMIT;

   EXCEPTION
       WHEN OTHERS THEN
           -- Handle exceptions and ensure the transaction is not partially committed
           ROLLBACK;
           RAISE;
   END;
   /
   ```

3. **Execute the Procedure in Parallel Sessions**:
   - In each session, call the procedure with a different GTT name:

   ```sql
   -- Session 1
   BEGIN
       Delete_Old_Audit_And_Link('temp_ids_to_delete_1');
   END;
   /

   -- Session 2
   BEGIN
       Delete_Old_Audit_And_Link('temp_ids_to_delete_2');
   END;
   /

   -- Session 3
   BEGIN
       Delete_Old_Audit_And_Link('temp_ids_to_delete_3');
   END;
   /

   -- Session 4
   BEGIN
       Delete_Old_Audit_And_Link('temp_ids_to_delete_4');
   END;
   /

   -- Session 5
   BEGIN
       Delete_Old_Audit_And_Link('temp_ids_to_delete_5');
   END;
   /
   ```

### Considerations

1. **Complexity**:
   - This approach adds complexity because you now have to manage multiple GTTs and ensure that the correct table is used in each session. It’s generally better to rely on Oracle’s built-in session isolation for GTTs unless you have a specific need.

2. **Maintenance**:
   - Maintaining multiple GTTs can lead to more administrative overhead. If the number of sessions increases, you may need to create more GTTs.

3. **Use Case**:
   - This approach might be useful if you have different sets of data that you want to process in complete isolation, even to the extent of not sharing the same GTT structure, or if you have different schema users that need separate temporary tables for compliance reasons.

### Typical Approach

Usually, you would:

- Use **one GTT** that’s reused across sessions, leveraging the session-specific isolation provided by Oracle.
- Each session works with its own data in the GTT, ensuring there’s no conflict or data leakage between sessions.
  
Using multiple GTTs is generally unnecessary unless there’s a specific requirement that mandates this approach. For most parallel processing scenarios, Oracle’s GTTs with session-specific data handling will be more than sufficient.


=##
CREATE OR REPLACE PROCEDURE Delete_Old_Audit_And_Link IS
BEGIN
    -- Step 1: Create a temporary table to store the IDs to delete
    EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE temp_ids_to_delete (
        id NUMBER
    ) ON COMMIT DELETE ROWS';

    -- Step 2: Insert the IDs that need to be deleted into the temporary table
    INSERT INTO temp_ids_to_delete (id)
    SELECT a.id
    FROM Audit a
    JOIN audit_link al ON a.id = al.id
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND al.object_type IN (3, 4, 5);

    -- Step 3: Delete from the audit_link table using the temporary table
    DELETE FROM audit_link al
    WHERE al.id IN (SELECT id FROM temp_ids_to_delete);

    -- Step 4: Delete from the Audit table using the temporary table
    DELETE FROM Audit a
    WHERE a.id IN (SELECT id FROM temp_ids_to_delete);

    -- Commit the transaction
    COMMIT;

    -- Step 5: Drop the temporary table
    EXECUTE IMMEDIATE 'DROP TABLE temp_ids_to_delete';

EXCEPTION
    WHEN OTHERS THEN
        -- Handle exceptions and ensure the temporary table is dropped
        EXECUTE IMMEDIATE 'DROP TABLE temp_ids_to_delete';
        RAISE;
END;
/


=#=#=#=

To achieve the goal of inserting data into both the `Audit` and `audit_link` tables in the archive database, verifying the successful insertion, and then deleting the rows from both tables in the main database, you can follow this approach:

1. **Insert Data into Archive Tables**: Insert the data from both `Audit` and `audit_link` tables in the main database into their corresponding tables in the archive database.
2. **Verify the Insertion**: Check whether the number of rows inserted into the archive tables matches the number of rows that need to be deleted.
3. **Delete from Main Tables**: If the verification is successful, delete the corresponding rows from both the `Audit` and `audit_link` tables in the main database.

Here is a PL/SQL procedure that implements this logic:

```sql
CREATE OR REPLACE PROCEDURE archive_and_delete_audit_data IS
    -- Variables to store the count of rows to be moved and actually inserted
    v_audit_count     NUMBER;
    v_audit_link_count NUMBER;
    v_audit_inserted  NUMBER;
    v_audit_link_inserted NUMBER;

BEGIN
    -- 1. Calculate the number of rows to be moved from the Audit table
    SELECT COUNT(*)
    INTO v_audit_count
    FROM Audit a
    JOIN audit_link al ON a.id = al.id
    WHERE a."DATE" < ADD_MONTHS(SYSDATE, -12)
      AND al.object_type IN (3, 4, 5);

    -- 2. Calculate the number of rows to be moved from the audit_link table
    SELECT COUNT(*)
    INTO v_audit_link_count
    FROM audit_link al
    WHERE EXISTS (
        SELECT 1
        FROM Audit a
        WHERE a.id = al.id
          AND a."DATE" < ADD_MONTHS(SYSDATE, -12)
          AND al.object_type IN (3, 4, 5)
    );

    -- 3. Insert rows from Audit table into the archive
    INSERT INTO audit@archive_db_link (id, "DATE", other_columns...)
    SELECT a.id, a."DATE", a.other_columns...
    FROM Audit a
    JOIN audit_link al ON a.id = al.id
    WHERE a."DATE" < ADD_MONTHS(SYSDATE, -12)
      AND al.object_type IN (3, 4, 5);

    -- 4. Insert rows from audit_link table into the archive
    INSERT INTO audit_link@archive_db_link (id, object_type, other_columns...)
    SELECT al.id, al.object_type, al.other_columns...
    FROM audit_link al
    WHERE EXISTS (
        SELECT 1
        FROM Audit a
        WHERE a.id = al.id
          AND a."DATE" < ADD_MONTHS(SYSDATE, -12)
          AND al.object_type IN (3, 4, 5)
    );

    -- 5. Verify that all rows were inserted into the archive Audit table
    SELECT COUNT(*)
    INTO v_audit_inserted
    FROM audit@archive_db_link a
    JOIN audit_link@archive_db_link al ON a.id = al.id
    WHERE a.id IN (
        SELECT a.id
        FROM Audit a
        JOIN audit_link al ON a.id = al.id
        WHERE a."DATE" < ADD_MONTHS(SYSDATE, -12)
          AND al.object_type IN (3, 4, 5)
    );

    -- 6. Verify that all rows were inserted into the archive audit_link table
    SELECT COUNT(*)
    INTO v_audit_link_inserted
    FROM audit_link@archive_db_link al
    WHERE al.id IN (
        SELECT al.id
        FROM audit_link al
        WHERE EXISTS (
            SELECT 1
            FROM Audit a
            WHERE a.id = al.id
              AND a."DATE" < ADD_MONTHS(SYSDATE, -12)
              AND al.object_type IN (3, 4, 5)
        )
    );

    -- 7. Proceed with deletion if the row counts match
    IF v_audit_inserted = v_audit_count AND v_audit_link_inserted = v_audit_link_count THEN
        -- Delete from the audit_link table in the main database
        DELETE FROM audit_link al
        WHERE EXISTS (
            SELECT 1
            FROM Audit a
            WHERE a.id = al.id
              AND a."DATE" < ADD_MONTHS(SYSDATE, -12)
              AND al.object_type IN (3, 4, 5)
        );

        -- Delete from the Audit table in the main database
        DELETE FROM Audit a
        WHERE a.id IN (
            SELECT a.id
            FROM Audit a
            JOIN audit_link al ON a.id = al.id
            WHERE a."DATE" < ADD_MONTHS(SYSDATE, -12)
              AND al.object_type IN (3, 4, 5)
        );

        COMMIT;
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Row count mismatch: Archiving failed');
    END IF;

END archive_and_delete_audit_data;
/
```

### Explanation:
- **Row Count Calculation**:
  - `v_audit_count` and `v_audit_link_count` are used to store the count of rows that need to be moved from the `Audit` and `audit_link` tables.
  
- **Insertion**:
  - Data from the `Audit` and `audit_link` tables in the main database are inserted into their corresponding tables in the archive database using `INSERT INTO ... SELECT`.

- **Verification**:
  - `v_audit_inserted` and `v_audit_link_inserted` store the count of rows that were successfully inserted into the archive tables. If these counts match the original counts, the procedure proceeds to delete the rows from the main tables.

- **Deletion**:
  - If the row counts match, the procedure deletes the corresponding rows from the `Audit` and `audit_link` tables in the main database.

- **Error Handling**:
  - If there is a mismatch in the row counts (indicating a possible failure in the archiving process), the procedure raises an error and does not delete the data from the main tables.

This procedure ensures that data is only deleted from the main tables after a successful transfer to the archive tables. Be sure to test the procedure thoroughly before deploying it in a production environment.


======
BEGIN
    -- Step 1: Insert into Archive Table via DB Link
    INSERT INTO archive_table@your_db_link (column1, column2, ..., your_date_column)
    SELECT column1, column2, ..., your_date_column
    FROM your_table
    WHERE your_date_column < ADD_MONTHS(SYSDATE, -36)
    AND your_date_column >= SYSDATE - INTERVAL '7' DAY;

    -- Step 2: Delete from Main Table
    DELETE FROM your_table
    WHERE your_date_column < ADD_MONTHS(SYSDATE, -36)
    AND your_date_column >= SYSDATE - INTERVAL '7' DAY;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/



SELECT * FROM your_table
WHERE your_date_column < ADD_MONTHS(SYSDATE, -36)
AND your_date_column >= SYSDATE - INTERVAL '7' DAY;



Delete on a table Audit for date column less than 1 year from current date and object_type column in the relational audit_link table for 3,4,5
Those 2 tables are joined by their primary_key id

Give an oracle sql query or procedure to achieve the data deletion 




WITH ids_to_delete AS (
    SELECT a.id
    FROM Audit a
    JOIN audit_link al ON a.id = al.id
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND al.object_type IN (3, 4, 5)
)
-- First delete from audit_link
DELETE FROM audit_link al
WHERE al.id IN (SELECT id FROM ids_to_delete);

-- Then delete from Audit
DELETE FROM Audit a
WHERE a.id IN (SELECT id FROM ids_to_delete);

COMMIT;




You're correct that after deleting the rows from the `audit_link` table, the `EXISTS` clause won't be able to find any matching rows in `audit_link` to delete from the `Audit` table. This would result in the records in the `Audit` table not being deleted as intended.

To correctly delete the records from both tables, you need to capture the `id`s of the records that match the criteria before deletion, and then use those `id`s to delete from both tables. Here's how you can do it:

### SQL Procedure to Delete from Both Tables

```sql
CREATE OR REPLACE PROCEDURE Delete_Old_Audit_And_Link IS
BEGIN
    -- Delete from the Audit table first to capture the ids to delete
    DELETE FROM Audit a
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND EXISTS (
        SELECT 1
        FROM audit_link al
        WHERE al.id = a.id
        AND al.object_type IN (3, 4, 5)
    )
    RETURNING a.id BULK COLLECT INTO :ids_to_delete;

    -- Delete from the audit_link table based on the captured ids
    FORALL i IN INDICES OF :ids_to_delete
        DELETE FROM audit_link al
        WHERE al.id = :ids_to_delete(i);

    -- Commit the transaction
    COMMIT;
END;
/
```

### Explanation:

1. **Deleting from `Audit` Table**:
   - The deletion starts from the `Audit` table. The `RETURNING` clause is used to capture the `id`s of the records that are deleted, storing them into a collection (e.g., a PL/SQL table or an array).

2. **Bulk Delete from `audit_link` Table**:
   - The `FORALL` construct is used to efficiently delete records from the `audit_link` table using the `id`s captured from the first deletion step. This ensures that we delete the correct corresponding records in `audit_link`.

3. **Transaction Control**:
   - Finally, the transaction is committed to ensure all deletions are finalized.

### Execution

To execute the procedure:

```sql
BEGIN
    Delete_Old_Audit_And_Link;
END;
/
```

### Alternative Approach: Using a Common Table Expression (CTE)

If you prefer not to use PL/SQL and collections, you can use a CTE approach that directly targets both tables:

```sql
WITH ids_to_delete AS (
    SELECT a.id
    FROM Audit a
    JOIN audit_link al ON a.id = al.id
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND al.object_type IN (3, 4, 5)
)
-- First delete from audit_link
DELETE FROM audit_link al
WHERE al.id IN (SELECT id FROM ids_to_delete);

-- Then delete from Audit
DELETE FROM Audit a
WHERE a.id IN (SELECT id FROM ids_to_delete);

COMMIT;
```

### Explanation:

1. **Common Table Expression (CTE)**:
   - The `WITH` clause creates a temporary result set containing the `id`s that meet the criteria.

2. **Deletion**:
   - First, it deletes from `audit_link` using the `id`s from the CTE.
   - Then, it deletes from `Audit` using the same `id`s.

3. **Commit**:
   - A `COMMIT` is issued after the deletions to ensure data consistency.

This method ensures that records are correctly removed from both tables without issues related to referential integrity or missing matching `id`s.






CREATE OR REPLACE PROCEDURE Delete_Old_Audit_And_Link IS
    -- Declare a collection (PL/SQL table) to store the IDs
    TYPE id_array IS TABLE OF Audit.id%TYPE;
    ids_to_delete id_array;
BEGIN
    -- Delete from Audit and capture the IDs being deleted
    DELETE FROM Audit a
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND a.id IN (
        SELECT al.id
        FROM audit_link al
        WHERE al.object_type IN (3, 4, 5)
    )
    RETURNING a.id BULK COLLECT INTO ids_to_delete;

    -- Delete from audit_link using the captured IDs
    FORALL i IN INDICES OF ids_to_delete
        DELETE FROM audit_link al WHERE al.id = ids_to_delete(i);

    -- Commit the transaction
    COMMIT;
END;
/



=====


CREATE OR REPLACE PROCEDURE Delete_Old_Audit_And_Link IS
    TYPE id_array IS TABLE OF Audit.id%TYPE;
    ids_to_delete id_array;
BEGIN
    -- Delete from Audit and capture the ids being deleted
    DELETE FROM Audit a
    WHERE a.date_column < ADD_MONTHS(SYSDATE, -12)
    AND a.id IN (
        SELECT al.id
        FROM audit_link al
        WHERE al.object_type IN (3, 4, 5)
    )
    RETURNING a.id BULK COLLECT INTO ids_to_delete;

    -- Delete from audit_link using the captured ids
    FORALL i IN INDICES OF ids_to_delete
        DELETE FROM audit_link al WHERE al.id = ids_to_delete(i);

    -- Commit the transaction
    COMMIT;
END;
/