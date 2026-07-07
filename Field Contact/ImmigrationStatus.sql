WITH base AS (
    SELECT
        fi.fldint_id,
        fi.fldint_date,
        fi.agency_code,
        fi.fldint_type_type,
        fi.fldint_type,
        ec.description AS type_desc,
        fi.summary
    FROM field_interviews fi
    INNER JOIN ejs_codes ec
        ON ec.code_type = fi.fldint_type_type
       AND ec.code = fi.fldint_type
    WHERE ec.description = 'Immigration Status'
),
people AS (
    SELECT
        fp.fldint_id,
        LISTAGG(TO_CHAR(fp.person_id), ', ') WITHIN GROUP (ORDER BY fp.person_id) AS person_ids
    FROM fldint_people fp
    GROUP BY fp.fldint_id
),
vehicles AS (
    SELECT
        fv.fldint_id,
        LISTAGG(TO_CHAR(fv.vehicle_id), ', ') WITHIN GROUP (ORDER BY fv.vehicle_id) AS vehicle_ids
    FROM fldint_vehicles fv
    GROUP BY fv.fldint_id
),
officers AS (
    SELECT
        fo.fldint_id,
        LISTAGG(fo.officer_id, ', ') WITHIN GROUP (ORDER BY fo.officer_id) AS officer_ids
    FROM fldint_officers fo
    GROUP BY fo.fldint_id
),
addresses AS (
    SELECT
        fa.fldint_id,
        LISTAGG(TO_CHAR(fa.address_id), ', ') WITHIN GROUP (ORDER BY fa.address_id) AS address_ids
    FROM fldint_addresses fa
    GROUP BY fa.fldint_id
),
businesses AS (
    SELECT
        fb.fldint_id,
        LISTAGG(fb.business_number, ', ') WITHIN GROUP (ORDER BY fb.business_number) AS business_numbers
    FROM fldint_businesses fb
    GROUP BY fb.fldint_id
),
gangs AS (
    SELECT
        fg.fldint_id,
        LISTAGG(TO_CHAR(fg.gang_id), ', ') WITHIN GROUP (ORDER BY fg.gang_id) AS gang_ids
    FROM fldint_gangs fg
    GROUP BY fg.fldint_id
)
SELECT
    b.*,
    p.person_ids,
    v.vehicle_ids,
    o.officer_ids,
    a.address_ids,
    bu.business_numbers,
    g.gang_ids
FROM base b
LEFT JOIN people p ON p.fldint_id = b.fldint_id
LEFT JOIN vehicles v ON v.fldint_id = b.fldint_id
LEFT JOIN officers o ON o.fldint_id = b.fldint_id
LEFT JOIN addresses a ON a.fldint_id = b.fldint_id
LEFT JOIN businesses bu ON bu.fldint_id = b.fldint_id
LEFT JOIN gangs g ON g.fldint_id = b.fldint_id
ORDER BY b.fldint_date DESC, b.fldint_id DESC;
