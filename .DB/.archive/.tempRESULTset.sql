
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