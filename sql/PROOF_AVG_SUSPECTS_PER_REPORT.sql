-- Query: rows behind AVG_SUSPECTS_PER_REPORT for shoplifting incidents (NIBRS 23C)
-- Purpose: data-vetting extract for suspect counts per report
-- Input: :report_year (example 2025)
--
-- Logic aligns to SHOPLIFTING_23C_METRICS.sql:
-- suspect_count counts DISTINCT INCIDENT_PEOPLE.INC_PER_ID where any of:
--   - role/relation indicates suspect/offender
--   - SUSPUS_USING_CODE is not null
-- and EXCLUDES people who were arrested on the same report/agency/person

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
suspect_counts AS (
    SELECT ip.inc_incident_id AS incident_id,
           COUNT(DISTINCT CASE WHEN a.arrest_id IS NULL THEN ip.inc_per_id END) AS suspect_count,
           SUM(CASE WHEN UPPER(NVL(ipr.role_type, '')) IN ('S','SO','S/O') THEN 1 ELSE 0 END) AS matched_role_type_rows,
           SUM(CASE WHEN UPPER(NVL(rc.role_desc, '')) LIKE '%SUSPECT%' OR UPPER(NVL(rc.role_desc, '')) LIKE '%OFFENDER%' THEN 1 ELSE 0 END) AS matched_role_desc_rows,
           SUM(CASE WHEN UPPER(NVL(rel.description, '')) LIKE '%SUSPECT%' THEN 1 ELSE 0 END) AS matched_suspect_rows,
           SUM(CASE WHEN UPPER(NVL(rel.description, '')) LIKE '%OFFENDER%' THEN 1 ELSE 0 END) AS matched_offender_rows,
           SUM(CASE WHEN ip.suspus_using_code IS NOT NULL THEN 1 ELSE 0 END) AS matched_suspus_rows,
           SUM(CASE WHEN UPPER(NVL(ip.reltn_relation_code, '')) IN ('S','O','SO','S/O')
                     OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%SUS%'
                     OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%OFF%'
                    THEN 1 ELSE 0 END) AS matched_relation_code_rows,
           SUM(CASE WHEN a.arrest_id IS NOT NULL THEN 1 ELSE 0 END) AS excluded_arrest_rows
      FROM incident_people ip
      JOIN incidents i
        ON i.incident_id = ip.inc_incident_id
      LEFT JOIN incident_person_roles ipr
        ON ipr.inc_per_id = ip.inc_per_id
      LEFT JOIN role_codes rc
        ON rc.role_type = ipr.role_type
      LEFT JOIN ejs_codes rel
        ON rel.code_type = ip.relation_code_type
       AND rel.code      = ip.reltn_relation_code
      LEFT JOIN arrests a
        ON a.inc_report_number = i.inc_report_number
       AND a.agency_code       = i.agncy_cd_agency_code
       AND a.person_id         = ip.per_person_id
     WHERE UPPER(NVL(ipr.role_type, '')) IN ('S','SO','S/O')
        OR UPPER(NVL(rc.role_desc, '')) LIKE '%SUSPECT%'
        OR UPPER(NVL(rc.role_desc, '')) LIKE '%OFFENDER%'
        OR UPPER(NVL(rel.description, '')) LIKE '%SUSPECT%'
        OR UPPER(NVL(rel.description, '')) LIKE '%OFFENDER%'
        OR UPPER(NVL(ip.reltn_relation_code, '')) IN ('S','O','SO','S/O')
        OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%SUS%'
        OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%OFF%'
        OR ip.suspus_using_code IS NOT NULL
     GROUP BY ip.inc_incident_id
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
    MAX(NVL(sc.suspect_count, 0)) AS suspect_count,
    MAX(NVL(sc.matched_role_type_rows, 0)) AS matched_role_type_rows,
    MAX(NVL(sc.matched_role_desc_rows, 0)) AS matched_role_desc_rows,
    MAX(NVL(sc.matched_suspect_rows, 0)) AS matched_suspect_rows,
    MAX(NVL(sc.matched_offender_rows, 0)) AS matched_offender_rows,
    MAX(NVL(sc.matched_suspus_rows, 0)) AS matched_suspus_rows,
    MAX(NVL(sc.matched_relation_code_rows, 0)) AS matched_relation_code_rows,
    MAX(NVL(sc.excluded_arrest_rows, 0)) AS excluded_arrest_rows
  FROM retail_incidents ri
  LEFT JOIN case_numbers cn
    ON cn.incident_id = ri.incident_id
  LEFT JOIN suspect_counts sc
    ON sc.incident_id = ri.incident_id
 GROUP BY ri.agency_code, ri.inc_report_number
 ORDER BY report_date, report_number;
