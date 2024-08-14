
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