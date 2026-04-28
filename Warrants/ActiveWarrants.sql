-- DBeaver runnable version (keeps terminating semicolon)
SELECT
    ew.warrant_id                          AS ew_warrant_id,
    ew.wsc_code                            AS ew_wsc_code,
    ew.wsc_code_type                       AS ew_wsc_code_type,
    ew.date_issued                         AS ew_date_issued,
    ew.received_date                       AS ew_received_date,
    ew.agency_code                         AS ew_agency_code,
    ac.agency_desc                         AS ew_agency_desc,
    ew.issuing_agency                      AS ew_issuing_agency,
    ac_iss.agency_desc                     AS ew_issuing_agency_desc,
    ew.charging_agency_code                AS ew_charging_agency_code,
    ac_chg.agency_desc                     AS ew_charging_agency_desc,
    ew.charging_agency_name                AS ew_charging_agency_name,
    ew.charging_agency_comment             AS ew_charging_agency_comment,
    ew.expunge                             AS ew_expunge,

    mn.per_person_id                       AS mn_person_id,
    mn.mn_id                               AS mn_mn_id,
    mn.fname                               AS mn_first_name,
    mn.mname                               AS mn_middle_name,
    mn.lname                               AS mn_last_name,
    mn.dob                                 AS mn_dob,
    mn.ssn                                 AS mn_ssn,

    p.person_id                            AS p_person_id,
    p.master_person_id                     AS p_master_person_id,
    mp.master_person_id                    AS mp_master_person_id,
    mp.race_code                           AS mp_race_code,
    mp.sex_code                            AS mp_sex_code,

    ld.dl_number                           AS subj_dl_number,
    ld.dl_state                            AS subj_dl_state,
    ld.dl_expiration                       AS subj_dl_expiration,

    la.address_id                          AS subj_address_id,
    la.address_type_code                   AS subj_address_type_code,
    la.official_address                    AS subj_official_address,
    addr.street_number                     AS subj_street_number,
    addr.dirct_cd_direction_code           AS subj_street_direction,
    addr.street_name                       AS subj_street_name,
    addr.street_cd_street_type_code        AS subj_street_type,
    addr.direct_suffix                     AS subj_street_suffix,
    addr.sub_number                        AS subj_sub_number,
    addr.city                              AS subj_city,
    addr.state_cd_state_code               AS subj_state,
    addr.zip5                              AS subj_zip5,
    addr.zip4                              AS subj_zip4,
    TRIM(
        NVL(addr.street_number,'') || ' ' ||
        NVL(addr.dirct_cd_direction_code,'') || ' ' ||
        NVL(addr.street_name,'') || ' ' ||
        NVL(addr.street_cd_street_type_code,'') || ' ' ||
        NVL(addr.direct_suffix,'') || ' ' ||
        NVL(addr.sub_number,'') || ', ' ||
        NVL(addr.city,'') || ', ' ||
        NVL(addr.state_cd_state_code,'') || ' ' ||
        NVL(addr.zip5,'')
    ) AS subj_address_summary,

    wr.warrant_reference_id                AS wr_warrant_reference_id,
    wr.reference_type                      AS wr_reference_type,
    wr.reference_type_code                 AS wr_reference_type_code,
    wr.reference_id                        AS wr_reference_id,

    wc.ewar_warrant_id                     AS wc_warrant_id,
    wc.cha_code                            AS wc_charge_code,
    wc.creator_date                        AS wc_creator_date,

    wfc.warrant_id                         AS wfc_warrant_id,
    wfc.freetext_charge_id                 AS wfc_freetext_charge_id,
    wfc.warrant_charge                     AS wfc_warrant_charge,
    wfc.creator_date                       AS wfc_creator_date,

    wac.warrant_id                         AS wac_warrant_id,
    wac.arrest_charge_code                 AS wac_arrest_charge_code,

    wso.log_id                             AS wso_log_id,
    wso.officer_id                         AS wso_officer_id,
    wso.served_date                        AS wso_served_date,

    wo.id                                  AS wo_assignment_id,
    wo.officer_id                          AS wo_officer_id,
    wo.start_date                          AS wo_start_date,
    wo.end_date                            AS wo_end_date,

    ofc.officer_id                         AS ofc_officer_id,
    ofc.internal_id                        AS ofc_badge_number,
    ofc.fname                              AS ofc_first_name,
    ofc.lname                              AS ofc_last_name,
    off_agency.agency_code                 AS ofc_agency_code,
    off_agency.agency_desc                 AS ofc_agency_desc,

    assgn_cmnt.ejs_comment_id              AS wo_comment_id,
    assgn_cmnt.ejs_comment                 AS wo_comment_text
FROM e_warrants ew
LEFT JOIN master_names mn
       ON mn.mn_id = ew.mn_mn_id
      AND mn.per_person_id = ew.mn_per_person_id
LEFT JOIN people p
       ON p.person_id = ew.mn_per_person_id
LEFT JOIN master_people mp
       ON mp.master_person_id = p.master_person_id
LEFT JOIN agency_codes ac
       ON ac.agency_code = ew.agency_code
LEFT JOIN agency_codes ac_iss
       ON ac_iss.agency_code = ew.issuing_agency
LEFT JOIN agency_codes ac_chg
       ON ac_chg.agency_code = ew.charging_agency_code
LEFT JOIN (
    SELECT x.per_person_id,
           x.id_number AS dl_number,
           x.state_cd_state_code AS dl_state,
           x.expiration AS dl_expiration
    FROM (
        SELECT mi.per_person_id,
               mi.id_number,
               mi.state_cd_state_code,
               mi.expiration,
               ROW_NUMBER() OVER (
                   PARTITION BY mi.per_person_id
                   ORDER BY NVL(mi.date_of_info, mi.creator_date) DESC, mi.misc_id_cntr DESC
               ) AS rn
        FROM misc_ids mi
        WHERE mi.misc_cd_misc_id_code = 'DL'
    ) x
    WHERE x.rn = 1
) ld
       ON ld.per_person_id = ew.mn_per_person_id
LEFT JOIN (
    SELECT x.person_id,
           x.address_id,
           x.address_type_code,
           x.official_address,
           x.date_of_info
    FROM (
        SELECT pa.person_id,
               pa.address_id,
               pa.address_type_code,
               pa.official_address,
               pa.date_of_info,
               ROW_NUMBER() OVER (
                   PARTITION BY pa.person_id
                   ORDER BY CASE WHEN pa.official_address = 'Y' THEN 1 ELSE 0 END DESC,
                            NVL(pa.date_of_info, pa.creator_date) DESC,
                            pa.person_address_id DESC
               ) AS rn
        FROM person_addresses pa
    ) x
    WHERE x.rn = 1
) la
       ON la.person_id = ew.mn_per_person_id
LEFT JOIN addresses addr
       ON addr.address_id = la.address_id
LEFT JOIN warrant_references wr
       ON wr.warrant_id = ew.warrant_id
LEFT JOIN warrant_charges wc
       ON wc.ewar_warrant_id = ew.warrant_id
LEFT JOIN warrant_freetext_charges wfc
       ON wfc.warrant_id = ew.warrant_id
LEFT JOIN warrant_arrest_charges wac
       ON wac.warrant_id = ew.warrant_id
LEFT JOIN warrant_serving_officers wso
       ON wso.warrant_id = ew.warrant_id
LEFT JOIN warrant_officers wo
       ON wo.warrant_id = ew.warrant_id
LEFT JOIN officers ofc
       ON ofc.officer_id = wo.officer_id
LEFT JOIN agency_codes off_agency
       ON off_agency.agency_code = ofc.agncy_cd_agency_code
LEFT JOIN ejs_comments assgn_cmnt
       ON assgn_cmnt.ejs_comment_id = wo.asgn_cmnt_id;
