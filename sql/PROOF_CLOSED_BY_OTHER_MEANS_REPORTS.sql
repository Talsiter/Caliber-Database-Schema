-- Query: rows behind CLOSED_BY_OTHER_MEANS_REPORTS for shoplifting incidents (NIBRS 23C)
-- Purpose: data-vetting extract for reports closed by means other than arrest
-- Input: :report_year (example 2025)
--
-- Logic aligns to SHOPLIFTING_23C_METRICS.sql:
--   closed_by_other_means = (is_open = 0 AND has_arrest = 0)

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
incident_open_status AS (
    SELECT
        ici.incident_id,
        MAX(CASE WHEN UPPER(NVL(ec.description, '')) LIKE '%OPEN%' THEN 1 ELSE 0 END) AS is_open,
        LISTAGG(DISTINCT ec.description, ' | ') WITHIN GROUP (ORDER BY ec.description) AS case_statuses
      FROM inc_case_inc_status_vw ici
      JOIN incident_cases ic
        ON ic.inc_case_id = ici.inc_case_id
      LEFT JOIN ejs_codes ec
        ON ec.code_type = ic.case_status_code_type
       AND ec.code      = ic.case_status_code
     GROUP BY ici.incident_id
),
arrest_flags AS (
    SELECT a.agency_code,
           a.inc_report_number,
           COUNT(DISTINCT a.arrest_id) AS arrest_count
      FROM arrests a
     WHERE a.inc_report_number IS NOT NULL
     GROUP BY a.agency_code, a.inc_report_number
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
    MAX(ios.case_statuses) AS case_statuses,
    NVL(MAX(af.arrest_count), 0) AS arrest_count
  FROM retail_incidents ri
  LEFT JOIN case_numbers cn
    ON cn.incident_id = ri.incident_id
  LEFT JOIN incident_open_status ios
    ON ios.incident_id = ri.incident_id
  LEFT JOIN arrest_flags af
    ON af.inc_report_number = ri.inc_report_number
   AND af.agency_code = ri.agency_code
 WHERE NVL(ios.is_open, 0) = 0
   AND NVL(af.arrest_count, 0) = 0
 GROUP BY ri.agency_code, ri.inc_report_number
 ORDER BY report_date, report_number;
