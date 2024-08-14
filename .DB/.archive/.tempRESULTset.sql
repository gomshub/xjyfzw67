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