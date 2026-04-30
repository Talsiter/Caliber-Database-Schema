SELECT DISTINCT
    TO_CHAR(i.report_date, 'YYYY') AS report_year,
    i.agncy_cd_agency_code AS agency_code,
    i.incident_id,
    i.inc_report_number AS report_number,
    ic.inc_case_number AS case_numbers,
    TRIM(
        REGEXP_REPLACE(
            NVL(a.street_number, '') || ' ' ||
            NVL(a.dirct_cd_direction_code, '') || ' ' ||
            NVL(a.street_name, '') || ' ' ||
            NVL(a.street_cd_street_type_code, '') || ' ' ||
            NVL(a.sub_number, '') || ', ' ||
            NVL(a.city, '') || ', ' ||
            NVL(a.state_cd_state_code, '') || ' ' ||
            NVL(a.zip5, '') ||
            CASE
                WHEN a.zip4 IS NOT NULL THEN '-' || TO_CHAR(a.zip4)
                ELSE ''
            END,
            ' +',
            ' '
        )
    ) AS offense_address,
    i.report_date,
    oc.offense_code,
    oc.offense_desc,
    o.place_place_code AS place_code,
    ep.description AS place_desc,
    no.nibrs_code,
    nc.nibrs_desc
FROM incidents i
JOIN offenses o
  ON o.inc_incident_id = i.incident_id
JOIN offense_codes oc
  ON oc.offense_code = o.offns_cd_offense_code
JOIN nibrs_offenses no
  ON no.offense_code = oc.offense_code
JOIN nibrs_codes nc
  ON nc.nibrs_code = no.nibrs_code
JOIN ejs_codes ep
  ON ep.code_type = o.place_code_type
 AND ep.code = o.place_place_code
LEFT JOIN inc_case_inc_status_vw ici
  ON ici.incident_id = i.incident_id
LEFT JOIN incident_cases ic
  ON ic.inc_case_id = ici.inc_case_id
JOIN incident_addresses ia
  ON ia.incident_id = i.incident_id
JOIN addresses a
  ON a.address_id = ia.address_id
