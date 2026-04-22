-- 39-14-103 - 26A 	-- UCR=26A (2 Records) -------------- SKIP Scaning
-- 39-14-104 - 26A  -- UCR=26A (165 Records) -------------- ADDED TO LIST (Muddy Water)


-- 39-14-103 - 23C 	-- UCR=23C (12 Records)
-- 39-14-146 		-- UCR=23C (167 Records)
-- 39-14-146 (A)(1) -- UCR=23C (27 Records)
-- 39-14-146 (A)(2) -- UCR=23C (1 Records)
-- 39-14-146 (A)(3) -- UCR=23C (0 Records)

-- 39-14-146 (A)(4) -- UCR=23C (0 Records)
-- 39-14-146 (A)(5) -- UCR=23C (0 Records)
-- 39-14-146 (A)(6) -- UCR=23C (0 Records)

-- 39-14-146 (A)(7) -- UCR=23C (0 Records)
-- This Totals 209 Records

-- Only 23C UCR's Total 207 Records


WITH retail_incidents AS (
    SELECT DISTINCT
           i.incident_id,
           i.inc_report_number,
           i.agncy_cd_agency_code AS agency_code,
           i.report_date,
           EXTRACT(YEAR FROM i.report_date) AS report_year,
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
      LEFT JOIN nibrs_offenses no
        ON no.offense_code = oc.offense_code
      LEFT JOIN nibrs_codes nc
        ON nc.nibrs_code = no.nibrs_code
      LEFT JOIN ejs_codes ep
        ON ep.code_type = o.place_code_type
       AND ep.code = o.place_place_code
     WHERE i.report_date IS NOT NULL
       AND EXTRACT(YEAR FROM i.report_date) = :report_year
       AND i.agncy_cd_agency_code = 'TN0830400'
       AND (
             UPPER(NVL(no.nibrs_code, '')) = '23C'
             OR UPPER(NVL(oc.offense_code, '')) IN ('39-14-103 - 26A', '39-14-104 - 26A')
           )
       --AND UPPER(NVL(i.inc_report_number, '')) = 'HDVL25-00400'
      
),
case_numbers AS (
    SELECT x.incident_id,
           LISTAGG(x.inc_case_number, ', ') WITHIN GROUP (ORDER BY x.inc_case_number) AS case_numbers
      FROM (
            SELECT DISTINCT
                   ici.incident_id,
                   ic.inc_case_number
              FROM inc_case_inc_status_vw ici
              JOIN incident_cases ic
                ON ic.inc_case_id = ici.inc_case_id
             WHERE ic.inc_case_number IS NOT NULL
           ) x
     GROUP BY x.incident_id
),
occurrence_addresses AS (
    SELECT x.incident_id,
           LISTAGG(x.occurrence_address, ' | ') WITHIN GROUP (ORDER BY x.occurrence_address) AS occurrence_addresses
      FROM (
            SELECT DISTINCT
                   ia.incident_id,
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
                   ) AS occurrence_address
              FROM incident_addresses ia
              JOIN addresses a
                ON a.address_id = ia.address_id
           ) x
     GROUP BY x.incident_id
)
SELECT
    ri.report_year,
    ri.agency_code,
    ri.incident_id,
    ri.inc_report_number AS report_number,
    cn.case_numbers,
    oa.occurrence_addresses AS offense_address,
    ri.report_date,
    ri.offense_code,
    ri.offense_desc,
    ri.place_code,
    ri.place_desc,
    ri.nibrs_code,
    ri.nibrs_desc
  FROM retail_incidents ri
  LEFT JOIN case_numbers cn
    ON cn.incident_id = ri.incident_id
  LEFT JOIN occurrence_addresses oa
    ON oa.incident_id = ri.incident_id
 ORDER BY ri.report_date, ri.inc_report_number, ri.incident_id, ri.offense_code;
