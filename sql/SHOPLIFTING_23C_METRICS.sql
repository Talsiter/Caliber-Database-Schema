-- Aggregate metrics query for shoplifting incidents (NIBRS 23C)
-- Input: :report_year
-- Fixed filters:
--   i.agncy_cd_agency_code = 'TN0830400'
--   no.nibrs_code = '23C'

WITH retail_incidents AS (
    SELECT DISTINCT
           i.incident_id,
           i.inc_report_number,
           i.agncy_cd_agency_code AS agency_code,
           i.report_date,
           EXTRACT(YEAR FROM i.report_date) AS report_year,
           oc.offense_code,
           oc.offense_desc,
           no.nibrs_code
      FROM incidents i
      JOIN offenses o
        ON o.inc_incident_id = i.incident_id
      JOIN offense_codes oc
        ON oc.offense_code = o.offns_cd_offense_code
      LEFT JOIN nibrs_offenses no
        ON no.offense_code = oc.offense_code
     WHERE i.report_date IS NOT NULL
       AND EXTRACT(YEAR FROM i.report_date) = :report_year
       AND i.agncy_cd_agency_code = 'TN0830400'
       AND UPPER(NVL(no.nibrs_code, '')) = '23C'
),
arrest_flags AS (
    SELECT a.inc_report_number,
           a.agency_code,
           1 AS has_arrest
      FROM arrests a
     WHERE a.inc_report_number IS NOT NULL
     GROUP BY a.inc_report_number, a.agency_code
),
status_flags AS (
    SELECT ic.inc_case_id,
           CASE
             WHEN UPPER(NVL(ec.description, '')) LIKE '%OPEN%' THEN 1
             ELSE 0
           END AS is_open
      FROM incident_cases ic
      LEFT JOIN ejs_codes ec
        ON ec.code_type = ic.case_status_code_type
       AND ec.code      = ic.case_status_code
),
incident_status AS (
    SELECT ici.incident_id,
           MAX(sf.is_open) AS is_open
      FROM inc_case_inc_status_vw ici
      LEFT JOIN status_flags sf
        ON sf.inc_case_id = ici.inc_case_id
     GROUP BY ici.incident_id
),
property_loss AS (
    SELECT ip.incsup_incident_id AS incident_id,
           SUM(CASE WHEN ip.prop_loss_code = '7' THEN NVL(ip.value, 0) ELSE 0 END) AS total_loss_value,
           SUM(CASE WHEN ip.status_code = '5' THEN NVL(ip.value, 0) ELSE 0 END) AS total_recovered_value
      FROM incident_properties ip
     GROUP BY ip.incsup_incident_id
),
suspect_counts AS (
    SELECT ip.inc_incident_id AS incident_id,
           COUNT(DISTINCT ip.inc_per_id) AS suspect_count
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
     WHERE (
            UPPER(NVL(ipr.role_type, '')) IN ('S','SO','S/O')
         OR UPPER(NVL(rc.role_desc, '')) LIKE '%SUSPECT%'
         OR UPPER(NVL(rc.role_desc, '')) LIKE '%OFFENDER%'
         OR UPPER(NVL(rel.description, '')) LIKE '%SUSPECT%'
         OR UPPER(NVL(rel.description, '')) LIKE '%OFFENDER%'
         OR UPPER(NVL(ip.reltn_relation_code, '')) IN ('S','O','SO','S/O')
         OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%SUS%'
         OR UPPER(NVL(ip.reltn_relation_code, '')) LIKE '%OFF%'
         OR ip.suspus_using_code IS NOT NULL
           )
       AND a.arrest_id IS NULL
     GROUP BY ip.inc_incident_id
),
vehicle_counts AS (
    SELECT iv.incident_id,
           COUNT(DISTINCT iv.vehicle_id) AS vehicle_count
      FROM incident_vehicles iv
     GROUP BY iv.incident_id
),
incident_metrics AS (
    SELECT
        ri.incident_id,
        ri.inc_report_number,
        ri.report_date,
        ri.agency_code,
        ri.offense_code,
        ri.offense_desc,
        NVL(af.has_arrest, 0) AS has_arrest,
        NVL(isf.is_open, 0) AS is_open,
        CASE
          WHEN NVL(isf.is_open, 0) = 0 AND NVL(af.has_arrest, 0) = 0 THEN 1
          ELSE 0
        END AS closed_by_other_means,
        NVL(pl.total_loss_value, 0) AS total_loss_value,
        NVL(pl.total_recovered_value, 0) AS total_recovered_value,
        NVL(sc.suspect_count, 0) AS suspect_count,
        NVL(vc.vehicle_count, 0) AS vehicle_count,
        CASE WHEN NVL(vc.vehicle_count, 0) > 0 THEN 1 ELSE 0 END AS has_vehicle_info
      FROM retail_incidents ri
      LEFT JOIN arrest_flags af
        ON af.inc_report_number = ri.inc_report_number
       AND af.agency_code       = ri.agency_code
      LEFT JOIN incident_status isf
        ON isf.incident_id = ri.incident_id
      LEFT JOIN property_loss pl
        ON pl.incident_id = ri.incident_id
      LEFT JOIN suspect_counts sc
        ON sc.incident_id = ri.incident_id
      LEFT JOIN vehicle_counts vc
        ON vc.incident_id = ri.incident_id
),
report_metrics AS (
    SELECT
        agency_code,
        inc_report_number,
        MIN(EXTRACT(YEAR FROM report_date)) AS report_year,
        MAX(has_arrest) AS has_arrest,
        MAX(is_open) AS is_open,
        MAX(closed_by_other_means) AS closed_by_other_means,
        MAX(total_loss_value) AS total_loss_value,
        MAX(total_recovered_value) AS total_recovered_value,
        MAX(suspect_count) AS suspect_count,
        MAX(vehicle_count) AS vehicle_count,
        MAX(has_vehicle_info) AS has_vehicle_info
      FROM incident_metrics
     GROUP BY agency_code, inc_report_number
)
SELECT
    :report_year AS report_year,
    COUNT(*) AS total_reports,
    SUM(has_arrest) AS reports_with_arrest,
    SUM(is_open) AS open_reports,
    SUM(closed_by_other_means) AS closed_by_other_means_reports,
    SUM(total_loss_value) AS summed_loss_value,
    SUM(total_recovered_value) AS summed_recovered_value,
    AVG(suspect_count) AS avg_suspects_per_report,
    SUM(has_vehicle_info) AS reports_with_vehicle_info,
    SUM(vehicle_count) AS total_vehicles_linked
  FROM report_metrics;
