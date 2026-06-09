SELECT
    CASE
        /* Juvenile arrest via incident-side age */
        WHEN EXISTS (
            SELECT 1
            FROM INCIDENT_PEOPLE ip
            JOIN INCIDENT_PERSON_ROLES r
              ON r.INC_PER_ID = ip.INC_PER_ID
            WHERE ip.INC_INCIDENT_ID = base.INCIDENT_ID
              AND r.ROLE_TYPE = 'A'
              AND CASE
                    WHEN REGEXP_LIKE(ip.APPROX_AGE, '^\d+$')
                    THEN TO_NUMBER(ip.APPROX_AGE)
                  END < 18
        ) THEN 'J'

        /* Juvenile arrest via arrest tables */
        WHEN EXISTS (
            SELECT 1
            FROM INCIDENT_PEOPLE ip
            JOIN INCIDENT_PERSON_ROLES r
              ON r.INC_PER_ID = ip.INC_PER_ID
            JOIN ARRESTS a
              ON a.PERSON_ID = ip.INC_PER_ID
            JOIN ARREST_PEOPLE ap
              ON ap.ARREST_ID = a.ARREST_ID
            WHERE ip.INC_INCIDENT_ID = base.INCIDENT_ID
              AND r.ROLE_TYPE = 'A'
              AND CASE
                    WHEN REGEXP_LIKE(ap.AGE_CODE, '^\d+$')
                    THEN TO_NUMBER(ap.AGE_CODE)
                  END BETWEEN 0 AND 17
        ) THEN 'J'

        /* Any arrest (adult or unknown age) */
        WHEN EXISTS (
            SELECT 1
            FROM INCIDENT_PEOPLE ip
            JOIN INCIDENT_PERSON_ROLES r
              ON r.INC_PER_ID = ip.INC_PER_ID
            WHERE ip.INC_INCIDENT_ID = base.INCIDENT_ID
              AND r.ROLE_TYPE = 'A'
        ) THEN 'A'

        ELSE NULL
    END AS ARREST,

    base.*
FROM (
    SELECT *
    FROM (
        SELECT
            i.*,
            ROW_NUMBER() OVER (
                PARTITION BY i.INCIDENT_ID, i.OFFENSE_NUMBER
                ORDER BY i.SUPP_SEQ DESC
            ) AS RN_SUPP
        FROM JS_INCIDENT_OFFENSE_VW i
    )
    WHERE RN_SUPP = 1
) base
WHERE base.UCR_NUMBER = (
    SELECT MIN(i2.UCR_NUMBER)
    FROM JS_INCIDENT_OFFENSE_VW i2
    WHERE i2.INCIDENT_ID = base.INCIDENT_ID
);
