-- Query: rows behind SUMMED_LOSS_VALUE for shoplifting incidents (NIBRS 23C)
-- Purpose: data-vetting extract for loss vs recovered values
-- Input: :report_year (example 2025)
--
-- Business rules:
--   TOTAL_LOSS_VALUE      = SUM(VALUE) where PROP_LOSS_CODE = '7' (Stolen)
--   TOTAL_RECOVERED_VALUE = SUM(VALUE) where STATUS_CODE    = '5' (Recovered)

WITH retail_incidents AS (
    SELECT DISTINCT
           i.incident_id,
           i.inc_report_number,
           i.agncy_cd_agency_code AS agency_code,
           i.report_date,
           EXTRACT(YEAR FROM i.report_date) AS report_year,
           oc.offense_code,
           oc.offense_desc,
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
     WHERE i.report_date IS NOT NULL
       AND EXTRACT(YEAR FROM i.report_date) = :report_year
       AND i.agncy_cd_agency_code = 'TN0830400'
       AND UPPER(NVL(no.nibrs_code, '')) = '23C'
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
property_loss AS (
    SELECT ip.incsup_incident_id AS incident_id,
           SUM(CASE WHEN ip.prop_loss_code = '7' THEN NVL(ip.value, 0) ELSE 0 END) AS total_loss_value,
           SUM(CASE WHEN ip.status_code = '5' THEN NVL(ip.value, 0) ELSE 0 END) AS total_recovered_value,
           COUNT(*) AS property_rows
      FROM incident_properties ip
     GROUP BY ip.incsup_incident_id
)
SELECT
    MIN(ri.report_year) AS report_year,
    ri.agency_code,
    ri.inc_report_number AS report_number,
    MIN(ri.incident_id) AS incident_id,
    MAX(cn.case_numbers) AS case_numbers,
    MIN(ri.report_date) AS report_date,
    LISTAGG(DISTINCT ri.offense_code, ', ') WITHIN GROUP (ORDER BY ri.offense_code) AS offense_codes,
    LISTAGG(DISTINCT ri.offense_desc, ' | ') WITHIN GROUP (ORDER BY ri.offense_desc) AS offense_descs,
    LISTAGG(DISTINCT ri.nibrs_code, ', ') WITHIN GROUP (ORDER BY ri.nibrs_code) AS nibrs_codes,
    LISTAGG(DISTINCT ri.nibrs_desc, ' | ') WITHIN GROUP (ORDER BY ri.nibrs_desc) AS nibrs_descs,
    MAX(NVL(pl.total_loss_value, 0)) AS total_loss_value,
    MAX(NVL(pl.total_recovered_value, 0)) AS total_recovered_value,
    MAX(NVL(pl.property_rows, 0)) AS property_rows
  FROM retail_incidents ri
  LEFT JOIN case_numbers cn
    ON cn.incident_id = ri.incident_id
  LEFT JOIN property_loss pl
    ON pl.incident_id = ri.incident_id
 GROUP BY ri.agency_code, ri.inc_report_number
 ORDER BY report_date, report_number;
