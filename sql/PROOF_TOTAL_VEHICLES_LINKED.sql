-- Query: rows behind TOTAL_VEHICLES_LINKED for shoplifting incidents (NIBRS 23C)
-- Purpose: data-vetting extract for vehicle links (one row per report + vehicle_id)
-- Input: :report_year (example 2025)

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
report_vehicle_links AS (
    SELECT DISTINCT
           ri.report_year,
           ri.agency_code,
           ri.inc_report_number AS report_number,
           ri.incident_id,
           ri.report_date,
           cn.case_numbers,
           iv.vehicle_id,
           iv.role_code,
           iv.status_code,
           iv.date_recovered
      FROM retail_incidents ri
      LEFT JOIN case_numbers cn
        ON cn.incident_id = ri.incident_id
      JOIN incident_vehicles iv
        ON iv.incident_id = ri.incident_id
)
SELECT
    rvl.report_year,
    rvl.agency_code,
    rvl.report_number,
    rvl.case_numbers,
    rvl.report_date,
    rvl.incident_id,
    rvl.vehicle_id,
    rvl.role_code,
    rvl.status_code,
    rvl.date_recovered
  FROM report_vehicle_links rvl
 ORDER BY rvl.report_date, rvl.report_number, rvl.vehicle_id;
