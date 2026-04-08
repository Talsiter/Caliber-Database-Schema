# Caliber-Database-Schema

## SQL Files

### 1) `sql/PROOF_TOTAL_REPORTS.sql`
Data-vetting extract (detail rows) for total reports.

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`

Output includes report/case identifiers and offense + NIBRS detail.

### 2) `sql/SHOPLIFTING_23C_METRICS.sql`
Aggregate metrics query using the same filter logic as `PROOF_TOTAL_REPORTS.sql`.

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`

Output columns:
- `REPORT_YEAR`
- `TOTAL_REPORTS`
- `REPORTS_WITH_ARREST`
- `OPEN_REPORTS`
- `CLOSED_BY_OTHER_MEANS_REPORTS`
- `SUMMED_LOSS_VALUE` (where `PROP_LOSS_CODE = '7'`)
- `SUMMED_RECOVERED_VALUE` (where `STATUS_CODE = '5'`)
- `AVG_SUSPECTS_PER_REPORT`
- `REPORTS_WITH_VEHICLE_INFO`
- `TOTAL_VEHICLES_LINKED`

### 3) `sql/PROOF_REPORTS_WITH_ARREST.sql`
Data-vetting extract for rows behind `REPORTS_WITH_ARREST` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`
- must have at least one matching arrest (`ARRESTS.INC_REPORT_NUMBER` + `ARRESTS.AGENCY_CODE`)

Additional arrest proof columns:
- `ARREST_COUNT`
- `ARREST_NUMBERS` (aggregated)
- offense/NIBRS values aggregated per report
- `FIRST_ARREST_DATE`
- `LAST_ARREST_DATE`


### 4) `sql/PROOF_OPEN_REPORTS.sql`
Data-vetting extract for rows behind `OPEN_REPORTS` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`
- must have an OPEN case status (derived from `INCIDENT_CASES` + `EJS_CODES` description)

Additional open-proof columns:
- `CASE_STATUSES` (aggregated case status descriptions)
- offense/NIBRS values aggregated per report


### 5) `sql/PROOF_CLOSED_BY_OTHER_MEANS_REPORTS.sql`
Data-vetting extract for rows behind `CLOSED_BY_OTHER_MEANS_REPORTS` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`
- must satisfy metrics logic: `is_open = 0` and `arrest_count = 0`

Additional closed-proof columns:
- `CASE_STATUSES` (aggregated case status descriptions)
- `ARREST_COUNT` (expected 0)
- offense/NIBRS values aggregated per report


### 6) `sql/PROOF_SUMMED_LOSS_VALUE.sql`
Data-vetting extract for rows behind `SUMMED_LOSS_VALUE` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`

Additional loss-proof columns:
- `TOTAL_LOSS_VALUE` (sum of `VALUE` where `PROP_LOSS_CODE = '7'`)
- `TOTAL_RECOVERED_VALUE` (sum of `VALUE` where `STATUS_CODE = '5'`)
- `PROPERTY_ROWS` (count of incident property rows reviewed)
- offense/NIBRS values aggregated per report

### 7) `sql/PROOF_AVG_SUSPECTS_PER_REPORT.sql`
Data-vetting extract for rows behind `AVG_SUSPECTS_PER_REPORT` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`

Additional suspect-proof columns:
- suspect logic excludes rows where the person is arrested on the same report
- `SUSPECT_COUNT`
- `MATCHED_ROLE_TYPE_ROWS`
- `MATCHED_ROLE_DESC_ROWS`
- `MATCHED_SUSPECT_ROWS`
- `MATCHED_OFFENDER_ROWS`
- `MATCHED_SUSPUS_ROWS`
- `MATCHED_RELATION_CODE_ROWS` (e.g., role codes like `SO` / `S/O`)
- `EXCLUDED_ARREST_ROWS` (rows removed from suspect count due to arrest)

### 8) `sql/PROOF_REPORTS_WITH_VEHICLE_INFO.sql`
Data-vetting extract for rows behind `REPORTS_WITH_VEHICLE_INFO` (one row per report).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`
- must have at least one linked vehicle (`VEHICLE_COUNT > 0`)

Additional vehicle-proof columns:
- `VEHICLE_COUNT`
- `VEHICLE_IDS` (aggregated distinct vehicle ids)

### 9) `sql/PROOF_TOTAL_VEHICLES_LINKED.sql`
Data-vetting extract for rows behind `TOTAL_VEHICLES_LINKED` (one row per report + vehicle_id link).

Filters:
- `:report_year`
- `AGNCY_CD_AGENCY_CODE = 'TN0830400'`
- mapped NIBRS code = `23C`
- includes only rows with linked `INCIDENT_VEHICLES`

Additional vehicle-proof columns:
- `VEHICLE_ID`
- `ROLE_CODE`
- `STATUS_CODE`
- `DATE_RECOVERED`
