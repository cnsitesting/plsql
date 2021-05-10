CREATE OR REPLACE PACKAGE pk_mbrhistory
AS
/******************************************************************************

   NAME:       pk_MbrHistory

   PURPOSE:

   REVISIONS:

   Ver        Date        Author            Description

   ---------  ----------  ----------------  ----------------------------------

   1.0                    Sujata Chowdhury

   1.1        10-13-03    Sujata             Modified

   1.2        06-14-04    Sujata             Modified

   1.3                    Sastry             Modified cursor cr_MbrPaidClaimLT

   1.4        08-24-04    Sujata             Modified

   1.5        09-15-04    Sujata             Modified

   1.6        11-07-04    Sujata

   1.7         11-08-04   Neel               DS-MECMS TEST-CLMP 05-00-0459

   1.8         11-23-04   Sastry             proceed flag

   1.9         11-23-04   Neel               DS-MECMS TEST-CLMP 05-00-0459

   1.10       12-02-04    Sujata             Modified a query for tuning purpose

   1.11       01-11-05    Sujata             DS-MECMS-TEST-CLMP-05-00-0539

   1.12       12-20-05    Sundar             Modified pr_insmbrhistory - v_adj_flag

                                             reset for line

   1.13       01-08-07    Bharathy           Made changes on mapping due to additional elements.

   1.14       8/30/2007   Morstein, A.       Removed references to fields in

                                             tmp_mbr_clm_history that don't exist

                                             Use Case: Claims LG2

   1.15      02/11/2008   Tamim              Change column treatment type code to

                                             billing provider treatment type code for ad_clm_hdr_derived_element

   1.16      08/11/2008   Sudeep P           Commenting the code which deltes the records from TMP_MBRHISTORY for the

                                             claims where the payment amount = 0.

   1.17      03/24/2010   Sudeep Prabhakaran Added global variable instead of re-executing the statement.
   1.18      07/26/2012   Sarbendu           Fetch First records from ad_clm_ln_dental_detail for the
                                             Input Claim Line 
   1.19      10/18/2012   Prakash Natesan        Added new procedure pr_ins_enc_mbrhistory for
                                            MIPRO00050493 - Edit to Identify Probable Duplicate Encounters                                             
   1.21       03/08/2013  Prakash Natesan   Changes in pr_insmbrhistory  and pr_getdataelement procedures  per MIPRO00053339  to 
                                            include header servicing identifier for 1230 edits processing  
   1.22      02/13/2014   Srinu babu J       Modified  pr_getdataelement and pr_insmbrhistory procedures                                                       
                                             per MIPRO00050883 to dervie and insert DRG CODE into tmp_mbr_clm_history table. 
    1.23      07/07/2014   Srinu babu J      Modified  pr_getclmdataelement as per MIPRO00052349 to dervie Hdr and line Srvcing provider location IID.     
    1.24      10/13/2014   Srinu babu J      Modified pr_insmbrhistory as Per MIPRO00061738 to include header DOS to 
                                             tmp_mbr_clm_history table.
    1.25      10/23/2014   Srinu babu J      Modified pr_ins_enc_mbrhistory as Per MIPRO00062095 to include line Copay amount to 
                                             tmp_mbr_enc_history table. 
    1.26       3/3/2015    Srinu babu J      Modified pr_getclmdataelement  and  pr_insmbrhistory as per CQ# MIPRO00061214.  
    1.27       7/17/2015   Srinu Babu J      Created new procedure pr_getclmdataelement_wip to get Claim information on WIP Tables.    
 Cloud RE 1.0 03/29/2016  Nivetha Somasundaram Cloud Re Engineering Changes
                                               1.0.1 MMF implementation
                                               1.0.2.Commented Code Cleanup
                                               removed vers 1.4, 1.7, Rev1.15, 1.17, v.1.18 changes 
   IL1.0      12/28/2020   Kensha             IMPACTDEV-5707 - Code Refactoring Commented code Clean up.                                            
   PARAMETERS:

   INPUT:

   OUTPUT:

   RETURNED VALUE:

   CALLED BY:

   ASSUMPTIONS:

   NOTES:

******************************************************************************/

   -----------------------------------------------------------------------------------------------------

   --------------------------------------------------------------------------------

   -- Global Variable Defined. (added version 1.17)
   gc_indctr_type_cid   indicator_type.indctr_type_cid%TYPE;

--------------------------------------------------------------------------------
   PROCEDURE pr_insmbrhistory (
      p_claim_header_sid   IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   );

   PROCEDURE pr_chkprcdrlimit (
      p_claim_header_sid     IN       NUMBER,
      p_hdr_srvc_from_date   IN       DATE,
      p_hdr_srvc_to_date     IN       DATE,
      p_year                 IN       VARCHAR2,
      p_created_by           IN       NUMBER,
      p_from_date            OUT      DATE,
      p_to_date              OUT      DATE,
      p_life_time_flag       OUT      VARCHAR2,
      p_err_code             OUT      VARCHAR2,
      p_err_msg              OUT      VARCHAR2
   );

   PROCEDURE pr_updclmhdrlnindicator_wip (
      p_claim_header_sid   IN       NUMBER,
      p_claim_line_sid     IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   );

   PROCEDURE pr_getclmdataelement (
      p_claim_header_sid              IN       ad_claim_header.claim_header_sid%TYPE,
      p_claim_line_sid                IN       ad_claim_line.claim_line_sid%TYPE,
      p_from_service_dt               IN       ad_claim_header.from_service_date%TYPE,
      p_to_service_dt                 IN       ad_claim_header.to_service_date%TYPE,
      p_pa_request_from_dt            IN       ad_claim_header.from_service_date%TYPE,
      p_pa_request_to_dt              IN       ad_claim_header.to_service_date%TYPE,
      p_old_claim_header_sid          IN       claim_header.claim_header_sid%TYPE,
      p_clm_submission_reason_lkpcd   OUT      ad_claim_header.claim_submission_reason_lkpcd%TYPE,
      p_copay_amount                  OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_payment_amount                OUT      clm_ln_payment_info.payment_amount%TYPE,
      p_paid_service_units            OUT      clm_ln_payment_info.paid_service_units%TYPE,
      p_rac_code                      OUT      ad_clm_ln_derived_element.rac_code%TYPE,
      p_clm_type_cid                  OUT      ad_claim_line.clm_type_cid%TYPE,
      p_trtmnt_type_code              OUT      ad_clm_ln_derived_element.blng_prvdr_trtmnt_type_code%TYPE,
      p_clsfctn_group_cid             OUT      ad_claim_line.clsfctn_group_cid%TYPE,
      p_procedure_iid                 OUT      ad_claim_line.procedure_iid%TYPE,
      p_follow_up_days                OUT      procedure_detail.follow_up_days%TYPE,
      p_prcdr_code                    OUT      VARCHAR2,
      p_revenue_iid                   OUT      ad_claim_line.revenue_iid%TYPE,
      p_revenue_code                  OUT      VARCHAR2,
      p_bi_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_bi_prvdr_type_code            OUT      VARCHAR2,
      p_spclty_code                   OUT      specialty_subspecialty.spclty_code%TYPE,
      p_subspclty_code                OUT      specialty_subspecialty.subspclty_code%TYPE,
      p_proc_pccm_indctor             OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_se_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_mdcr_parta_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_parta_deductible_amt%TYPE,
      p_mdcr_partb_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_partb_deductible_amt%TYPE,
      p_primary_diag_code             OUT      VARCHAR2,
      p_tooth_cid                     OUT      ad_clm_ln_dental_detail.tooth_cid%TYPE,
      p_mdfr_code1                    OUT      ad_claim_line.mdfr_code1%TYPE,
      p_mdfr_code2                    OUT      ad_claim_line.mdfr_code2%TYPE,
      p_mdfr_code3                    OUT      ad_claim_line.mdfr_code3%TYPE,
      p_mdfr_code4                    OUT      ad_claim_line.mdfr_code4%TYPE,
      p_surface_cid1                  OUT      ad_clm_ln_dental_detail.surface1_cid%TYPE,
      p_surface_cid2                  OUT      ad_clm_ln_dental_detail.surface2_cid%TYPE,
      p_surface_cid3                  OUT      ad_clm_ln_dental_detail.surface3_cid%TYPE,
      p_surface_cid4                  OUT      ad_clm_ln_dental_detail.surface4_cid%TYPE,
      p_surface_cid5                  OUT      ad_clm_ln_dental_detail.surface5_cid%TYPE,
      p_quadrant_cid1                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn1_cid%TYPE,
      p_quadrant_cid2                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn2_cid%TYPE,
      p_quadrant_cid3                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn3_cid%TYPE,
      p_quadrant_cid4                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn4_cid%TYPE,
      p_pa_utilised_amount1           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units1            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid1                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_pa_utilised_amount2           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units2            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid2                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_lo_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_ld_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_billed_amount                 OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_pa_rqst_prcdr_sid1            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_pa_rqst_prcdr_sid2            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_txnmy_code                    OUT      ad_clm_ln_derived_element.txnmy_code%TYPE,
      p_quadrant_cid5                 OUT      ad_clm_ln_oral_cvty_dsgntn_dtl.oral_cavity_dsgntn5_cid%TYPE,
      p_patient_status_lkpcd          OUT      ad_clm_hdr_admission_detail.patient_status_lkpcd%TYPE,
      p_spl_clm_indctr                OUT      ad_clm_hdr_x_indicator.indctr_option_code%TYPE,
      p_allowed_amount                OUT      NUMBER,
      p_oth_pyr_paid_amount           OUT      NUMBER,
      p_high_risk_ob_care_enh_amt     OUT      NUMBER,
      p_mnl_price_flag                OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_medicare_flag                 OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_hdr_srvcng_lctn_identifier    OUT      prvdr_lctn_identifier.idntfr%TYPE,-- Changes for MIPRO00053339
      p_drg_code                      OUT      ad_claim_header.drg_code%TYPE,--changes for MIPRO00050883
      p_sbmtd_mdfr_code1              OUT      ad_claim_line.mdfr_code1%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code2              OUT      ad_claim_line.mdfr_code2%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code3              OUT      ad_claim_line.mdfr_code3%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code4              OUT      ad_claim_line.mdfr_code4%TYPE, --Changes for MIPRO00061214
      p_err_code                      OUT      VARCHAR2,
      p_err_msg                       OUT      VARCHAR2
   );
      PROCEDURE pr_ins_enc_mbrhistory (
      p_claim_header_sid   IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   );

    PROCEDURE pr_getclmdataelement_wip (
      p_claim_header_sid              IN       ad_claim_header.claim_header_sid%TYPE,
      p_claim_line_sid                IN       ad_claim_line.claim_line_sid%TYPE,
      p_from_service_dt               IN       ad_claim_header.from_service_date%TYPE,
      p_to_service_dt                 IN       ad_claim_header.to_service_date%TYPE,
      p_pa_request_from_dt            IN       ad_claim_header.from_service_date%TYPE,
      p_pa_request_to_dt              IN       ad_claim_header.to_service_date%TYPE,
      p_old_claim_header_sid          IN       claim_header.claim_header_sid%TYPE,
      p_clm_submission_reason_lkpcd   OUT      ad_claim_header.claim_submission_reason_lkpcd%TYPE,
      p_copay_amount                  OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_payment_amount                OUT      clm_ln_payment_info.payment_amount%TYPE,
      p_paid_service_units            OUT      clm_ln_payment_info.paid_service_units%TYPE,
      p_rac_code                      OUT      ad_clm_ln_derived_element.rac_code%TYPE,
      p_clm_type_cid                  OUT      ad_claim_line.clm_type_cid%TYPE,
      p_trtmnt_type_code              OUT      ad_clm_ln_derived_element.blng_prvdr_trtmnt_type_code%TYPE,
      p_clsfctn_group_cid             OUT      ad_claim_line.clsfctn_group_cid%TYPE,
      p_procedure_iid                 OUT      ad_claim_line.procedure_iid%TYPE,
      p_follow_up_days                OUT      procedure_detail.follow_up_days%TYPE,
      p_prcdr_code                    OUT      VARCHAR2,
      p_revenue_iid                   OUT      ad_claim_line.revenue_iid%TYPE,
      p_revenue_code                  OUT      VARCHAR2,
      p_bi_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_bi_prvdr_type_code            OUT      VARCHAR2,
      p_spclty_code                   OUT      specialty_subspecialty.spclty_code%TYPE,
      p_subspclty_code                OUT      specialty_subspecialty.subspclty_code%TYPE,
      p_proc_pccm_indctor             OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_se_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_mdcr_parta_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_parta_deductible_amt%TYPE,
      p_mdcr_partb_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_partb_deductible_amt%TYPE,
      p_primary_diag_code             OUT      VARCHAR2,
      p_tooth_cid                     OUT      ad_clm_ln_dental_detail.tooth_cid%TYPE,
      p_mdfr_code1                    OUT      ad_claim_line.mdfr_code1%TYPE,
      p_mdfr_code2                    OUT      ad_claim_line.mdfr_code2%TYPE,
      p_mdfr_code3                    OUT      ad_claim_line.mdfr_code3%TYPE,
      p_mdfr_code4                    OUT      ad_claim_line.mdfr_code4%TYPE,
      p_surface_cid1                  OUT      ad_clm_ln_dental_detail.surface1_cid%TYPE,
      p_surface_cid2                  OUT      ad_clm_ln_dental_detail.surface2_cid%TYPE,
      p_surface_cid3                  OUT      ad_clm_ln_dental_detail.surface3_cid%TYPE,
      p_surface_cid4                  OUT      ad_clm_ln_dental_detail.surface4_cid%TYPE,
      p_surface_cid5                  OUT      ad_clm_ln_dental_detail.surface5_cid%TYPE,
      p_quadrant_cid1                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn1_cid%TYPE,
      p_quadrant_cid2                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn2_cid%TYPE,
      p_quadrant_cid3                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn3_cid%TYPE,
      p_quadrant_cid4                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn4_cid%TYPE,
      p_pa_utilised_amount1           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units1            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid1                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_pa_utilised_amount2           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units2            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid2                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_lo_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_ld_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_billed_amount                 OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_pa_rqst_prcdr_sid1            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_pa_rqst_prcdr_sid2            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_txnmy_code                    OUT      ad_clm_ln_derived_element.txnmy_code%TYPE,
      p_quadrant_cid5                 OUT      ad_clm_ln_oral_cvty_dsgntn_dtl.oral_cavity_dsgntn5_cid%TYPE,
      p_patient_status_lkpcd          OUT      ad_clm_hdr_admission_detail.patient_status_lkpcd%TYPE,
      p_spl_clm_indctr                OUT      ad_clm_hdr_x_indicator.indctr_option_code%TYPE,
      p_allowed_amount                OUT      NUMBER,
      p_oth_pyr_paid_amount           OUT      NUMBER,
      p_high_risk_ob_care_enh_amt     OUT      NUMBER,
      p_mnl_price_flag                OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_medicare_flag                 OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_hdr_srvcng_lctn_identifier    OUT      prvdr_lctn_identifier.idntfr%TYPE,-- Changes for MIPRO00053339
      p_drg_code                      OUT      ad_claim_header.drg_code%TYPE,--changes for MIPRO00050883
      p_sbmtd_mdfr_code1              OUT      ad_claim_line.mdfr_code1%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code2              OUT      ad_claim_line.mdfr_code2%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code3              OUT      ad_claim_line.mdfr_code3%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code4              OUT      ad_claim_line.mdfr_code4%TYPE, --Changes for MIPRO00061214
      p_err_code                      OUT      VARCHAR2,
      p_err_msg                       OUT      VARCHAR2
   );



END pk_mbrhistory;
/

CREATE OR REPLACE PACKAGE BODY pk_mbrhistory
AS
/******************************************************************************
  NAME:       pk_MbrHistory
   PURPOSE:
   REVISIONS:
   Ver        Date        Author            Description
   ---------  ----------  ----------------  ----------------------------------
   1.0                    Sujata Chowdhury
   1.2        11/05/2008  Tamim             MI Adjustments are always at header level,
                                            removed the logic to check if it's a header or line
                                            level adjustment based on the parent TCN ending with 000.
   1.3        11/21/2008  Tamim             Changed the date logic to always check for the beginning
                                            date to expand it to the beginning of the year or end of the
                                            year based on the partA and partB amounts
   1.4        12/12/2008  Tamim             Changed to exclude the blng_prvdr_lctn_iid NOT NULL check.
   1.5        01/08/2008  Tamim             Changed to include the actual claim_header_sid to log errors.
   1.6        01/27/2009  Tamim             Included logic to handle history claims that are inpatient
                                          clm_type_cid = 2
  1.7       03/24/2010   Sudeep Prabhakaran Some modifications to improve performance.
                                            1. Added function to use the variable as global so that it executes once.
                                            2. Merged tow different codes to make it one (for LO and LD).
                                             3. Commented the use of table (old_new_orgn_dstntn_cd_mapping).
                                             4. Made changes to use actual index as HINTS in main cursor.
                                             5. Removed claim header hit twice and now getting parent TCN value before hand.
   1.8      10/21/2010    Tamim              Added invoice_type_lkpcd to lifetime_claim and tmp_mbr_clm_history
   1.9      7/25/2011     Tamim              Changed to populate the manual price indicator and medicare indicator
   1.10     11/10/2011    Tamim              Changed to filter encounters from the mbr history call
   1.18      07/26/2012   Sarbendu           Fetch First records from ad_clm_ln_dental_detail for the
                                             Input Claim Line 
   1.19      10/18/2012   Prakash Natesan        Added new procedure pr_ins_enc_mbrhistory for
                                            MIPRO00050493 - Edit to Identify Probable Duplicate Encounters                                             
   1.20       03/01/2013  Prakash Natesan   Added a new condition in pr_insmbrhistory procedure  per MIPRO00049929 -"
                                             For Professional claims if Place of  service or Line Facility type value is "24" and billing 
                                             provider specialty is "B364" and sub specialty is "C999" then while populating 
                                             temp member history table insert billing provider NPI for servicing provider.                                          
   1.21       03/08/2013  Prakash Natesan   Changes in pr_insmbrhistory  and pr_getdataelement procedures  per MIPRO00053339  to 
                                            include header servicing identifier for 1230 edits processing    
   1.22      02/13/2014   Srinu babu J       Modified  pr_getdataelement and pr_insmbrhistory procedures                                                       
                                             per MIPRO00050883 to dervie and insert DRG CODE into tmp_mbr_clm_history table. 
   1.23      07/07/2014   Srinu babu J       Modified  pr_getclmdataelement as per MIPRO00052349 to dervie Hdr and line Srvcing provider location IID.  
   1.24      10/31/2018    Srinu Babu J     Changes for performance improvement  for Oracle 12c for CQ#MIPRO00094434     
   1.25      10/14/2019    Vijaya Lakshmi   Changes made for the CQ MIPRO00096760 to check the prvdr_lctn_identifier and prvdr_lctn_iid from the table ad_clm_hdr_x_prvdr_lctn.
   IL1.0      12/28/2020   Kensha             IMPACTDEV-5707 - Code Refactoring Commented code Clean up.                                            

   PARAMETERS:
   INPUT:
   OUTPUT:
   RETURNED VALUE:
   CALLED BY:
   ASSUMPTIONS:
   NOTES:
******************************************************************************/--- Added function as part of version 1.7 changes.
   FUNCTION fn_getspecialclaimindctr
      RETURN indicator_type.indctr_type_cid%TYPE
   IS
      v_indctr_type_cid   indicator_type.indctr_type_cid%TYPE   := NULL;
   BEGIN
      SELECT indctr_type_cid
        INTO v_indctr_type_cid
        FROM indicator_type
       WHERE indctr_type_desc = 'SPECIAL CLAIM INDICATOR';

      RETURN v_indctr_type_cid;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_indctr_type_cid;
   END fn_getspecialclaimindctr;

   PROCEDURE pr_insmbrhistory (
      p_claim_header_sid   IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   )
   IS
      v_lo_reference_identification   ad_clm_ln_reference_info.reference_identification%TYPE;
      v_ld_reference_identification   ad_clm_ln_reference_info.reference_identification%TYPE;
      v_clm_source_code               claim_header.clm_source_code%TYPE;
      v_billed_amount                 ad_clm_ln_amount.clm_amount_value%TYPE                        := 0;
      v_procedure_iid                 procedure_detail.procedure_iid%TYPE;
      v_revenue_iid                   procedure_detail.procedure_iid%TYPE;
      v_claim_line_sid                tmp_mbr_clm_history.claim_line_sid%TYPE;
      v_claim_header_sid              tmp_mbr_clm_history.claim_header_sid%TYPE;
      v_mbr_sid                       tmp_mbr_clm_history.mbr_sid%TYPE;
      v_prcdr_code                    tmp_mbr_clm_history.prcdr_code%TYPE;
      v_revenue_code                  tmp_mbr_clm_history.revenue_code%TYPE;
      v_mdfr_code1                    tmp_mbr_clm_history.mdfr_code1%TYPE;
      v_mdfr_code2                    tmp_mbr_clm_history.mdfr_code1%TYPE;
      v_mdfr_code3                    tmp_mbr_clm_history.mdfr_code1%TYPE;
      v_mdfr_code4                    tmp_mbr_clm_history.mdfr_code1%TYPE;
      v_sbmtd_mdfr_code1              tmp_mbr_clm_history.sbmtd_mdfr_code_1%TYPE;   --modified as per CQ#61214
      v_sbmtd_mdfr_code2              tmp_mbr_clm_history.sbmtd_mdfr_code_1%TYPE;   --modified as per CQ#61214
      v_sbmtd_mdfr_code3              tmp_mbr_clm_history.sbmtd_mdfr_code_1%TYPE;   --modified as per CQ#61214
      v_sbmtd_mdfr_code4              tmp_mbr_clm_history.sbmtd_mdfr_code_1%TYPE;   --modified as per CQ#61214
      v_trtmnt_type_code              tmp_mbr_clm_history.trtmnt_type_code%TYPE;
      v_rac_code                      tmp_mbr_clm_history.rac_code%TYPE;
      v_paid_service_units            tmp_mbr_clm_history.paid_service_units%TYPE;
      v_follow_up_days                tmp_mbr_clm_history.follow_up_days%TYPE;
      v_payment_amount                tmp_mbr_clm_history.payment_amount%TYPE;
      v_primary_diagnosis_code        tmp_mbr_clm_history.primary_diagnosis_code%TYPE;
      v_spclty_code                   tmp_mbr_clm_history.spclty_code%TYPE;
      v_subspclty_code                tmp_mbr_clm_history.subspclty_code%TYPE;
      v_clm_type_cid                  tmp_mbr_clm_history.clm_type_cid%TYPE;
      v_clsfctn_group_cid             tmp_mbr_clm_history.clsfctn_group_cid%TYPE;
      v_surface_cid1                  tmp_mbr_clm_history.surface_cid1%TYPE;
      v_surface_cid2                  tmp_mbr_clm_history.surface_cid1%TYPE;
      v_surface_cid3                  tmp_mbr_clm_history.surface_cid1%TYPE;
      v_surface_cid4                  tmp_mbr_clm_history.surface_cid1%TYPE;
      v_surface_cid5                  tmp_mbr_clm_history.surface_cid1%TYPE;
      v_tooth_cid                     tmp_mbr_clm_history.tooth_cid%TYPE;
      v_sbmt_fclty_bill_clsfctn_sid   tmp_mbr_clm_history.sbmt_fclty_bill_clsfctn_sid%TYPE;
      v_claim_sbmsn_reason_lkpcd      tmp_mbr_clm_history.claim_submission_reason_lkpcd%TYPE;
      v_facility_type_code            tmp_mbr_clm_history.facility_type_code%TYPE;
      v_bi_prvdr_lctn_idntfr          tmp_mbr_clm_history.billing_prvdr_lctn_identifier%TYPE;
      v_bi_prvdr_type_code            tmp_mbr_clm_history.billing_prvdr_type_code%TYPE;
      v_se_prvdr_lctn_idntfr          tmp_mbr_clm_history.service_prvdr_lctn_identifier%TYPE;
      v_mdcr_parta_deductible_amt     tmp_mbr_clm_history.medicare_parta_deductible_amt%TYPE;
      v_mdcr_partb_deductible_amt     tmp_mbr_clm_history.medicare_partb_deductible_amt%TYPE;
      v_procedure_pccm_indicator      tmp_mbr_clm_history.procedure_pccm_indicator%TYPE;
      v_quadrant_cid1                 tmp_mbr_clm_history.quadrant_cid1%TYPE;
      v_quadrant_cid2                 tmp_mbr_clm_history.quadrant_cid2%TYPE;
      v_quadrant_cid3                 tmp_mbr_clm_history.quadrant_cid3%TYPE;
      v_quadrant_cid4                 tmp_mbr_clm_history.quadrant_cid4%TYPE;
      v_clm_ln_copay_amount           tmp_mbr_clm_history.clm_ln_copay_amount%TYPE                  := 0;
      v_pa_utilised_amount1           tmp_mbr_clm_history.pa_utilised_amount1%TYPE                  := 0;
      v_pa_utilised_units1            tmp_mbr_clm_history.pa_utilised_units1%TYPE                   := 0;
      v_pa_rqst_sid1                  tmp_mbr_clm_history.pa_rqst_sid1%TYPE;
      v_pa_utilised_amount2           tmp_mbr_clm_history.pa_utilised_amount2%TYPE                  := 0;
      v_pa_utilised_units2            tmp_mbr_clm_history.pa_utilised_units2%TYPE                   := 0;
      v_pa_rqst_sid2                  tmp_mbr_clm_history.pa_rqst_sid2%TYPE;
      v_to_date                       VARCHAR2 (10);
      v_life_time_flag                VARCHAR2 (1)                                                  := 'N';
      v_life_time_flag1               VARCHAR2 (1)                                                  := 'N';
      v_year                          VARCHAR2 (4);
      v_parent_tcn                    ad_claim_header.parent_tcn%TYPE;
      v_curr_clm_from_service_date    VARCHAR2 (10);
      v_curr_clm_to_service_date      VARCHAR2 (10);
      v_from_service_date1            VARCHAR2 (100);
      v_to_service_date1              VARCHAR2 (100);
      v_prvdr_lctn_iid                NUMBER (17);
      v_cnt                           NUMBER (5)                                                    := 0;
      v_admit_date                    DATE;
      v_curr_clm_from_serv_date_dt    ad_claim_header.from_service_date%TYPE;
      v_curr_clm_to_serv_date_dt      ad_claim_header.to_service_date%TYPE;
      v_from_date_temp_dt             DATE;
      v_to_date_temp_dt               DATE;
      v_from_date_cm_dt               DATE;
      v_to_date_cm_dt                 DATE;
      v_limit_from_date_dt            DATE;
      v_limit_to_date_dt              DATE;
      v_errlog_code                   VARCHAR2 (10);
      v_errlog_msg                    VARCHAR2 (500);
      v_old_claim_header_sid          ad_claim_header.claim_header_sid%TYPE;
      v_old_claim_line_sid            ad_claim_line.claim_line_sid%TYPE;
      v_cnt1                          NUMBER                                                        := 0;
      v_proceed_flag                  VARCHAR (1)                                                   := 'Y';
      v_adj_flag                      VARCHAR (1);
      v_cursor_cnt                    NUMBER                                                        := 0;
      v_parameter_list                VARCHAR2 (2000);
      v_pa_rqst_prcdr_sid1            pa_request_procedure.pa_rqst_prcdr_sid%TYPE;
      v_pa_rqst_prcdr_sid2            pa_request_procedure.pa_rqst_prcdr_sid%TYPE;
      v_txnmy_code                    ad_clm_ln_derived_element.txnmy_code%TYPE;
      v_quadrant_cid5                 ad_clm_ln_oral_cvty_dsgntn_dtl.oral_cavity_dsgntn5_cid%TYPE;
      v_patient_status_lkpcd          ad_clm_hdr_admission_detail.patient_status_lkpcd%TYPE;
      v_tcn_date                      ad_claim_header.tcn_date%TYPE;
      v_spl_clm_indctr                ad_clm_hdr_x_indicator.indctr_option_code%TYPE;
      v_discharge_dt                  ad_claim_header.discharge_date%TYPE;
      v_proc_iid                      ad_claim_line.procedure_iid%TYPE;
      v_diagnosis_iid                 ad_claim_line.primary_diagnosis_iid%TYPE;
      v_allowed_amount                NUMBER;
      v_oth_pyr_paid_amount           NUMBER;
      v_high_risk_ob_care_enh_amt     NUMBER;
      v_clm_submission_reason_lkpcd   ad_claim_header.claim_submission_reason_lkpcd%TYPE;
      v_invoice_type_lkpcd            ad_claim_header.invoice_type_lkpcd%TYPE;
      v_mnl_price_flag                ad_clm_ln_x_indicator.indctr_option_code%TYPE;
      v_medicare_flag                 ad_clm_ln_x_indicator.indctr_option_code%TYPE;
      v_primary_pa_rqst_sid           ad_claim_header.primary_pa_rqst_sid%TYPE;
      v_hdr_srvcng_lctn_identifier    tmp_mbr_clm_history.hdr_srvc_prvdr_lctn_identifier%TYPE;-- Changes for MIPRO00053339
      v_drg_code                      ad_claim_header.drg_code%TYPE;-- Changes for MIPRO00050883
      v_hdr_from_serv_date            tmp_mbr_clm_history.header_from_srvc_date%TYPE;-- Changes for MIPRO00061738
      v_hdr_to_serv_date              tmp_mbr_clm_history.header_to_srvc_date%TYPE;-- Changes for MIPRO00061738
      v_orig_tcn                      ad_claim_header.original_tcn%TYPE;
      --
      e_getelement_excep              EXCEPTION;


      -- Removing old hint and adding the actual hint to be used per version 1.7.
      CURSOR cr_mbrpaidclaim (p_mbr_sid IN MEMBER.mbr_sid%TYPE, p_from_date_temp_dt IN DATE, p_to_date_temp_dt IN DATE)
      IS
         SELECT     /*+ INDEX (CHM XIF15AD_CLAIM_HEADER) INDEX(cl XIF26AD_CLAIM_LINE) */    
                DISTINCT cl.claim_header_sid, cl.claim_line_sid,
                         TRUNC (NVL (cl.from_service_date, chm.from_service_date)),
                         TRUNC (NVL (cl.to_service_date, chm.to_service_date)),
                         DECODE (chm.invoice_type_lkpcd, 'I', NULL, cl.facility_type_code) facility_type_code,
                         chm.discharge_date, cl.procedure_iid, cl.revenue_iid, cl.primary_diagnosis_iid,
                         chm.admission_date, chm.tcn_date, chm.invoice_type_lkpcd, chm.primary_pa_rqst_sid ,  -- 1.8
                         TRUNC (chm.from_service_date),TRUNC (chm.to_service_date)-- Changes for MIPRO00061738
                    FROM ad_claim_header chm, ad_claim_line cl
                   WHERE chm.mbr_sid = p_mbr_sid
                     AND chm.claim_header_sid = cl.claim_header_sid
                     AND cl.bsns_status_type_cid = 8
                     AND cl.bsns_status_cid = 71
                     AND chm.clm_enc_flag = 'FFS'   -- Added for Rev 1.24  
                     and original_tcn<>v_orig_tcn 
                     AND NVL (cl.from_service_date, chm.from_service_date) <= p_to_date_temp_dt
                     AND NVL (NVL (cl.to_service_date, cl.from_service_date),
                              NVL (chm.to_service_date, chm.from_service_date)
                             ) >= p_from_date_temp_dt;

      CURSOR cr_mbrpaidclaimlt (p_mbr_sid IN MEMBER.mbr_sid%TYPE)
      IS
         SELECT *
           FROM lifetime_claim
          WHERE mbr_sid = p_mbr_sid
            AND oprtnl_flag='A';
             
   BEGIN
      p_err_code :=  PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;     --vers Cloud RE 1.0.1
      p_err_msg := 'Success';
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, 0));
      v_parameter_list := v_parameter_list || '&' || 'p_created_by=' || TO_CHAR (NVL (p_created_by, 0));
      /*Get trun sys date*/

      --- Assigning Global Variable version 1.17....
      gc_indctr_type_cid := fn_getspecialclaimindctr;

      /*Get claim details*/
      SELECT TO_CHAR (ch.from_service_date, 'YYYY'), TO_CHAR (ch.from_service_date, 'MM/DD/YYYY'),
             TO_CHAR (ch.to_service_date, 'MM/DD/YYYY'), ch.from_service_date, ch.to_service_date,
             ch.sbmt_fclty_bill_clsfctn_sid, ch.claim_submission_reason_lkpcd, ch.blng_prvdr_lctn_iid, ch.mbr_sid,
             ch.parent_tcn,
             DECODE (ch.blng_prvdr_idntfr_type_cid, 7, ch.blng_prvdr_lctn_identifier, NULL) billing_idntfr,
             clm_source_code,original_tcn
        INTO v_year, v_curr_clm_from_service_date,
             v_curr_clm_to_service_date, v_curr_clm_from_serv_date_dt, v_curr_clm_to_serv_date_dt,
             v_sbmt_fclty_bill_clsfctn_sid, v_claim_sbmsn_reason_lkpcd, v_prvdr_lctn_iid, v_mbr_sid,
             v_parent_tcn,
             v_bi_prvdr_lctn_idntfr,
             v_clm_source_code,v_orig_tcn
        FROM claim_header ch   --Bharathy changed from Ad to wip table
       WHERE ch.claim_header_sid = p_claim_header_sid;

      IF NVL (v_clm_source_code, '99') = '04' THEN -- Do nothing if it's encounter Rev1.10
         RETURN;
      END IF;

      /*Delete records from TMP_MBR_CLM_HISTORY for the member sid*/
         DELETE      tmp_mbr_clm_history
               WHERE mbr_sid = v_mbr_sid;

         DELETE      tmp_mbr_clm_hist_status
               WHERE mbr_sid = v_mbr_sid;

      COMMIT;

      /*Provider lctn iid <> 0*/
      IF v_bi_prvdr_lctn_idntfr IS NULL
--- Changed as per 1.17 only if the MMIS value is NULL then go to provider location identifier table.
      THEN
         /*Get billing provider details*/
         BEGIN
            SELECT idntfr
              INTO v_bi_prvdr_lctn_idntfr
              FROM prvdr_lctn_identifier pl
             WHERE pl.prvdr_lctn_iid = v_prvdr_lctn_iid
               AND idntfr_type_cid = 7
               -- Previously it was 3 changed to 7 as per discussion with Anil.
               AND from_date <= v_curr_clm_from_serv_date_dt
               AND TO_DATE >= v_curr_clm_to_serv_date_dt
               AND status_cid = 2
               AND oprtnl_flag = 'A';

            v_bi_prvdr_type_code := NULL;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_bi_prvdr_lctn_idntfr := NULL;
               v_bi_prvdr_type_code := NULL;
         END;
      END IF;

      /*Call procedure to check prcdr limit*/
      pr_chkprcdrlimit (p_claim_header_sid,
                        v_curr_clm_from_serv_date_dt,
                        v_curr_clm_to_serv_date_dt,
                        v_year,
                        p_created_by,
                        v_limit_from_date_dt,
                        v_limit_to_date_dt,
                        v_life_time_flag,
                        p_err_code,
                        p_err_msg
                       );

      IF p_err_code <>  PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS  THEN  --vers Cloud RE 1.0.1 
         RETURN;
      END IF;

      /*Convert char date type to date*/
      v_from_date_cm_dt := v_curr_clm_from_serv_date_dt;
      v_to_date_cm_dt := v_curr_clm_to_serv_date_dt;

      IF v_life_time_flag = 'Y' THEN
         v_life_time_flag1 := v_life_time_flag;
      END IF;

      /*Derive from date temp*/
      IF ((v_limit_from_date_dt IS NULL) OR (v_from_date_cm_dt < v_limit_from_date_dt)) THEN
         v_from_date_temp_dt := v_from_date_cm_dt;
      ELSE
         v_from_date_temp_dt := v_limit_from_date_dt;
         v_limit_from_date_dt := NULL;
      END IF;

      /*Derive to date temp*/
      IF ((v_limit_to_date_dt IS NULL) OR (v_to_date_cm_dt > v_limit_to_date_dt)) THEN
         v_to_date_temp_dt := v_to_date_cm_dt;
      ELSE
         v_to_date_temp_dt := v_limit_to_date_dt;
         v_limit_to_date_dt := NULL;
      END IF;


      IF v_life_time_flag = 'Y' THEN
         v_life_time_flag1 := v_life_time_flag;
      END IF;

      --Derive the from date temp
      IF v_limit_from_date_dt IS NOT NULL THEN
         IF v_limit_from_date_dt < v_from_date_temp_dt THEN
            v_from_date_temp_dt := v_limit_from_date_dt;
         END IF;

         --Assign null
         v_limit_from_date_dt := NULL;
      END IF;

      IF v_limit_to_date_dt IS NOT NULL THEN
         IF v_limit_to_date_dt > v_to_date_temp_dt THEN
            v_to_date_temp_dt := v_limit_to_date_dt;
         END IF;

         --Assign null
         v_to_date := NULL;
      END IF;

      --Rev1.3 Changed to expand the dates to include the whole year's data
      IF TO_CHAR (v_from_date_temp_dt, 'YYYY') = TO_CHAR (v_curr_clm_from_serv_date_dt, 'YYYY') THEN
         v_from_date_temp_dt := TO_DATE ('01/01/' || TO_CHAR (v_from_date_temp_dt, 'YYYY'), 'mm/dd/yyyy');
      END IF;

      IF TO_CHAR (v_to_date_temp_dt, 'YYYY') = TO_CHAR (v_curr_clm_to_serv_date_dt, 'YYYY') THEN
         v_to_date_temp_dt := TO_DATE ('12/31/' || TO_CHAR (v_to_date_temp_dt, 'YYYY'), 'mm/dd/yyyy');
      END IF;

      -- End Rev1.3
      v_adj_flag := '';

      IF v_claim_sbmsn_reason_lkpcd IN ('7') THEN
         BEGIN
            SELECT claim_header_sid
              INTO v_old_claim_header_sid
              FROM ad_claim_header
             WHERE tcn = v_parent_tcn;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_old_claim_header_sid := NULL;
         END;

         v_adj_flag := 'H';
      END IF;

      /*Open the cursor to be processed*/
      FOR cr_mbrpaidclaimlt_rec IN cr_mbrpaidclaimlt (v_mbr_sid) LOOP
         /*Process for each record of the opened cursor*/
         BEGIN
            v_proceed_flag := 'Y';
            v_cursor_cnt := 1;

            /* - Added by Sundar 20050607 */
            IF v_adj_flag = 'H' THEN
             BEGIN   -- Rev 1.24 changes start
                   SELECT   'N'
                     INTO   v_proceed_flag
                     FROM   ad_claim_line
                    WHERE   claim_header_sid = v_old_claim_header_sid
                            AND claim_line_sid = cr_mbrpaidclaimlt_rec.claim_line_sid;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                      v_proceed_flag := 'Y';
            END;-- Rev 1.24 changes start

            ELSIF v_adj_flag = 'L' THEN
               IF cr_mbrpaidclaimlt_rec.claim_line_sid = v_old_claim_line_sid THEN
                  v_proceed_flag := 'N';
               ELSE
                  v_proceed_flag := 'Y';
               END IF;
            END IF;

            /* - Added by Sundar - 20050607*/
            IF v_proceed_flag = 'Y' THEN
               --Insert into tmp mbr clm history
               INSERT INTO tmp_mbr_clm_history
                           (claim_header_sid, claim_line_sid, mbr_sid,
                            from_service_date,
                            to_service_date, prcdr_code,
                            mdfr_code1, mdfr_code2,
                            mdfr_code3, mdfr_code4,
                            trtmnt_type_code, rac_code,
                            paid_service_units, follow_up_days,
                            payment_amount, primary_diagnosis_code,
                            spclty_code, subspclty_code,
                            clm_type_cid, clsfctn_group_cid,
                            tooth_cid, surface_cid1,
                            surface_cid2, surface_cid3,
                            surface_cid4, surface_cid5,
                            sbmt_fclty_bill_clsfctn_sid,
                            claim_submission_reason_lkpcd,
                            facility_type_code,
                            billing_prvdr_lctn_identifier,
                            billing_prvdr_type_code,
                            service_prvdr_lctn_identifier,
                            procedure_pccm_indicator, oprtnl_flag, quadrant_cid1,
                            quadrant_cid2, quadrant_cid3, quadrant_cid4,
                            revenue_code, clm_ln_copay_amount,
                            pa_rqst_sid1, pa_utilised_amount1,
                            pa_utilised_units1, pa_rqst_sid2,
                            pa_utilised_amount2, pa_utilised_units2,
                            created_by, created_date, billed_amount,
                            admit_date_time, origin_code,
                            dstntn_code, pa_rqst_prcdr_sid1,
                            pa_rqst_prcdr_sid2, txnmy_code,
                            quadrant_cid5, patient_status_lkpcd,
                            tcn_date, spl_clm_indctr,
                            discharge_date, procedure_iid,
                            revenue_iid, diagnosis_iid,
                            invoice_type_lkpcd,   --1.8
                                               mnl_price_indctr,   -- 1.9
                            medicare_indctr,   --1.9
                                            primary_pa_rqst_sid,
                                --Changes start for CQ#70112
                                allowed_amount ,
                                drug_code,
                                srvcng_spclty_code ,
                                srvcng_subspclty_code,
                                drg_code  ,
                                medicare_parta_deductible_amt  ,
                                medicare_partb_deductible_amt  ,
                                prcdr_unit_rate  ,
                                hdr_srvc_prvdr_lctn_identifier  ,
                                header_from_srvc_date  ,
                                header_to_srvc_date  ,
                                sbmtd_mdfr_code_1 ,
                                sbmtd_mdfr_code_2 ,
                                sbmtd_mdfr_code_3,
                                sbmtd_mdfr_code_4
                                --Changes end for CQ#70112
                           )
                    VALUES (cr_mbrpaidclaimlt_rec.claim_header_sid, cr_mbrpaidclaimlt_rec.claim_line_sid, v_mbr_sid,
                            TRUNC (cr_mbrpaidclaimlt_rec.from_service_date),
                            TRUNC (cr_mbrpaidclaimlt_rec.to_service_date), cr_mbrpaidclaimlt_rec.prcdr_code,
                            cr_mbrpaidclaimlt_rec.mdfr_code1, cr_mbrpaidclaimlt_rec.mdfr_code2,
                            cr_mbrpaidclaimlt_rec.mdfr_code3, cr_mbrpaidclaimlt_rec.mdfr_code4,
                            cr_mbrpaidclaimlt_rec.trtmnt_type_code, cr_mbrpaidclaimlt_rec.rac_code,
                            cr_mbrpaidclaimlt_rec.paid_service_units, cr_mbrpaidclaimlt_rec.follow_up_days,
                            cr_mbrpaidclaimlt_rec.payment_amount, cr_mbrpaidclaimlt_rec.primary_diagnosis_code,
                            cr_mbrpaidclaimlt_rec.spclty_code, cr_mbrpaidclaimlt_rec.subspclty_code,
                            cr_mbrpaidclaimlt_rec.clm_type_cid, cr_mbrpaidclaimlt_rec.clsfctn_group_cid,
                            cr_mbrpaidclaimlt_rec.tooth_cid, cr_mbrpaidclaimlt_rec.surface_cid1,
                            cr_mbrpaidclaimlt_rec.surface_cid2, cr_mbrpaidclaimlt_rec.surface_cid3,
                            cr_mbrpaidclaimlt_rec.surface_cid4, cr_mbrpaidclaimlt_rec.surface_cid5,
                            cr_mbrpaidclaimlt_rec.sbmt_fclty_bill_clsfctn_sid,
                            cr_mbrpaidclaimlt_rec.claim_submission_reason_lkpcd,
                            cr_mbrpaidclaimlt_rec.facility_type_code,
                            cr_mbrpaidclaimlt_rec.billing_prvdr_lctn_identifier,
                            cr_mbrpaidclaimlt_rec.billing_prvdr_type_code,
                        -- Start changes for MIPRO00049929
                            CASE WHEN cr_mbrpaidclaimlt_rec.invoice_type_lkpcd ='P' AND  cr_mbrpaidclaimlt_rec.facility_type_code='24'
                            AND cr_mbrpaidclaimlt_rec.spclty_code='B364' AND cr_mbrpaidclaimlt_rec.subspclty_code='C999'
                            THEN  cr_mbrpaidclaimlt_rec.billing_prvdr_lctn_identifier
                            ELSE
                            cr_mbrpaidclaimlt_rec.service_prvdr_lctn_identifier
                            END 
                        -- End changes for MIPRO00049929
                            ,cr_mbrpaidclaimlt_rec.procedure_pccm_indicator, 'A', cr_mbrpaidclaimlt_rec.quadrant_cid1,
                            v_quadrant_cid2, cr_mbrpaidclaimlt_rec.quadrant_cid3, cr_mbrpaidclaimlt_rec.quadrant_cid4,
                            cr_mbrpaidclaimlt_rec.revenue_code, cr_mbrpaidclaimlt_rec.clm_ln_copay_amount,
                            cr_mbrpaidclaimlt_rec.pa_rqst_sid1, cr_mbrpaidclaimlt_rec.pa_utilised_amount1,
                            cr_mbrpaidclaimlt_rec.pa_utilised_units1, cr_mbrpaidclaimlt_rec.pa_rqst_sid2,
                            cr_mbrpaidclaimlt_rec.pa_utilised_amount2, cr_mbrpaidclaimlt_rec.pa_utilised_units2,
                            p_created_by, SYSDATE, cr_mbrpaidclaimlt_rec.billed_amount,
                            cr_mbrpaidclaimlt_rec.admit_date_time, cr_mbrpaidclaimlt_rec.origin_code,
                            cr_mbrpaidclaimlt_rec.dstntn_code, cr_mbrpaidclaimlt_rec.pa_rqst_prcdr_sid1,
                            cr_mbrpaidclaimlt_rec.pa_rqst_prcdr_sid2, cr_mbrpaidclaimlt_rec.txnmy_code,
                            cr_mbrpaidclaimlt_rec.quadrant_cid5, cr_mbrpaidclaimlt_rec.patient_status_lkpcd,
                            cr_mbrpaidclaimlt_rec.tcn_date, cr_mbrpaidclaimlt_rec.spl_clm_indctr,
                            cr_mbrpaidclaimlt_rec.discharge_date, cr_mbrpaidclaimlt_rec.procedure_iid,
                            cr_mbrpaidclaimlt_rec.revenue_iid, cr_mbrpaidclaimlt_rec.diagnosis_iid,
                            cr_mbrpaidclaimlt_rec.invoice_type_lkpcd, cr_mbrpaidclaimlt_rec.mnl_price_indctr,
                            cr_mbrpaidclaimlt_rec.medicare_indctr, cr_mbrpaidclaimlt_rec.primary_pa_rqst_sid,
                            --Changes start for CQ#70112
                            cr_mbrpaidclaimlt_rec.allowed_amount ,
                            cr_mbrpaidclaimlt_rec.drug_code,
                            cr_mbrpaidclaimlt_rec.srvcng_spclty_code ,
                            cr_mbrpaidclaimlt_rec.srvcng_subspclty_code,
                            cr_mbrpaidclaimlt_rec.drg_code  ,
                            cr_mbrpaidclaimlt_rec.medicare_parta_deductible_amt  ,
                            cr_mbrpaidclaimlt_rec.medicare_partb_deductible_amt  ,
                            cr_mbrpaidclaimlt_rec.prcdr_unit_rate  ,
                            cr_mbrpaidclaimlt_rec.hdr_srvc_prvdr_lctn_identifier  ,
                            cr_mbrpaidclaimlt_rec.header_from_srvc_date  ,
                            cr_mbrpaidclaimlt_rec.header_to_srvc_date  ,
                            cr_mbrpaidclaimlt_rec.sbmtd_mdfr_code_1 ,
                            cr_mbrpaidclaimlt_rec.sbmtd_mdfr_code_2 ,
                            cr_mbrpaidclaimlt_rec.sbmtd_mdfr_code_3,
                            cr_mbrpaidclaimlt_rec.sbmtd_mdfr_code_4
                            --Changes end for CQ#70112
                           );
            END IF;   

            --Assign out parameters
            p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;   --vers Cloud RE 1.0.1
            p_err_msg := 'Successful....';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_err_code := '1';
               p_err_msg := 'No data found....';

               --Insert error log
               INSERT INTO tmp_mbr_clm_hist_status
                           (claim_header_sid, mbr_sid, status_cid, excptn_detail, date_time
                           )
                    VALUES (p_claim_header_sid, v_mbr_sid, 2, SUBSTR (p_err_msg, 1, 250), SYSDATE
                           );
         END;
      END LOOP;

      COMMIT;


      --Process paid claim
      OPEN cr_mbrpaidclaim (v_mbr_sid, v_from_date_temp_dt, v_to_date_temp_dt);

      /*Process for each record of the opened cursor*/
      LOOP
         BEGIN
            --Check flag values
            FETCH cr_mbrpaidclaim
             INTO v_claim_header_sid, v_claim_line_sid, v_from_service_date1, v_to_service_date1, v_facility_type_code,
                  v_discharge_dt, v_proc_iid, v_revenue_iid, v_diagnosis_iid, v_admit_date, v_tcn_date,
                  v_invoice_type_lkpcd, v_primary_pa_rqst_sid,
                  v_hdr_from_serv_date,v_hdr_to_serv_date;--changes as per MIPRO000461738

            EXIT WHEN cr_mbrpaidclaim%NOTFOUND;
            v_proceed_flag := 'Y';
            v_cursor_cnt := 1;

            IF v_adj_flag = 'H' THEN

             BEGIN   -- Rev 1.24 changes start
                   SELECT   'N'
                     INTO   v_proceed_flag
                     FROM   ad_claim_line
                    WHERE   claim_header_sid = v_old_claim_header_sid
                            AND claim_line_sid = v_claim_line_sid;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                   v_proceed_flag := 'Y';
            END;-- Rev 1.24 changes start

            ELSIF v_adj_flag = 'L' THEN
               IF v_claim_line_sid = v_old_claim_line_sid THEN
                  v_proceed_flag := 'N';
               ELSE
                  v_proceed_flag := 'Y';
               END IF;
            END IF;
             BEGIN   -- Rev 1.24 changes start
                   SELECT   'N'
                     INTO   v_proceed_flag
                     FROM   tmp_mbr_clm_history
                    WHERE   claim_header_sid = v_claim_header_sid
                            AND claim_line_sid = v_claim_line_sid;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                   NULL;
            END;-- Rev 1.24 changes start

            IF v_proceed_flag = 'Y' THEN
               --Call the procedure to get the claim elements
               pr_getclmdataelement (v_claim_header_sid,
                                     v_claim_line_sid,
                                     v_from_service_date1,
                                     v_to_service_date1,
                                     v_curr_clm_from_serv_date_dt,
                                     v_curr_clm_to_serv_date_dt,
                                     p_claim_header_sid,
                                     v_clm_submission_reason_lkpcd,
                                     v_clm_ln_copay_amount,
                                     v_payment_amount,
                                     v_paid_service_units,
                                     v_rac_code,
                                     v_clm_type_cid,
                                     v_trtmnt_type_code,
                                     v_clsfctn_group_cid,
                                     v_procedure_iid,
                                     v_follow_up_days,
                                     v_prcdr_code,
                                     v_revenue_iid,
                                     v_revenue_code,
                                     v_bi_prvdr_lctn_idntfr,
                                     v_bi_prvdr_type_code,
                                     v_spclty_code,
                                     v_subspclty_code,
                                     v_procedure_pccm_indicator,
                                     v_se_prvdr_lctn_idntfr,
                                     v_mdcr_parta_deductible_amt,
                                     v_mdcr_partb_deductible_amt,
                                     v_primary_diagnosis_code,
                                     v_tooth_cid,
                                     v_mdfr_code1,
                                     v_mdfr_code2,
                                     v_mdfr_code3,
                                     v_mdfr_code4,
                                     v_surface_cid1,
                                     v_surface_cid2,
                                     v_surface_cid3,
                                     v_surface_cid4,
                                     v_surface_cid5,
                                     v_quadrant_cid1,
                                     v_quadrant_cid2,
                                     v_quadrant_cid3,
                                     v_quadrant_cid4,
                                     v_pa_utilised_amount1,
                                     v_pa_utilised_units1,
                                     v_pa_rqst_sid1,
                                     v_pa_utilised_amount2,
                                     v_pa_utilised_units2,
                                     v_pa_rqst_sid2,
                                     v_lo_reference_identification,
                                     v_ld_reference_identification,
                                     v_billed_amount,
                                     v_pa_rqst_prcdr_sid1,
                                     v_pa_rqst_prcdr_sid2,
                                     v_txnmy_code,
                                     v_quadrant_cid5,
                                     v_patient_status_lkpcd,
                                     v_spl_clm_indctr,
                                     v_allowed_amount,
                                     v_oth_pyr_paid_amount,
                                     v_high_risk_ob_care_enh_amt,
                                     v_mnl_price_flag,
                                     v_medicare_flag,
                                     v_hdr_srvcng_lctn_identifier,-- Changes for MIPRO00053339
                                     v_drg_code,-- Changes for MIPRO00053339
                                     v_sbmtd_mdfr_code1,  --Changes for CQ#61214
                                     v_sbmtd_mdfr_code2,  --Changes for CQ#61214
                                     v_sbmtd_mdfr_code3,  --Changes for CQ#61214
                                     v_sbmtd_mdfr_code4,  --Changes for CQ#61214
                                     p_err_code,
                                     p_err_msg
                                    );

               --Check for error code
               IF p_err_code <> PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS THEN --vers Cloud RE 1.0.1
                  RAISE e_getelement_excep;
               END IF;
            END IF;   

            IF v_proceed_flag = 'Y' THEN
               --Insert into tmp mbr clm history
               INSERT INTO tmp_mbr_clm_history
                           (claim_header_sid, claim_line_sid, mbr_sid, from_service_date, to_service_date,
                            prcdr_code, mdfr_code1, mdfr_code2, mdfr_code3, mdfr_code4, trtmnt_type_code,
                            rac_code, paid_service_units, follow_up_days, payment_amount,
                            primary_diagnosis_code, spclty_code, subspclty_code, clm_type_cid,
                            clsfctn_group_cid, tooth_cid, surface_cid1, surface_cid2, surface_cid3,
                            surface_cid4, surface_cid5, sbmt_fclty_bill_clsfctn_sid,
                            claim_submission_reason_lkpcd, facility_type_code, billing_prvdr_lctn_identifier,
                            billing_prvdr_type_code, service_prvdr_lctn_identifier, procedure_pccm_indicator,
                            oprtnl_flag, quadrant_cid1, quadrant_cid2, quadrant_cid3, quadrant_cid4, revenue_code,
                            clm_ln_copay_amount, pa_rqst_sid1, pa_utilised_amount1, pa_utilised_units1,
                            pa_rqst_sid2, pa_utilised_amount2, pa_utilised_units2, created_by, created_date,
                            billed_amount, admit_date_time, origin_code,
                            dstntn_code, pa_rqst_prcdr_sid1, pa_rqst_prcdr_sid2, txnmy_code,
                            quadrant_cid5, patient_status_lkpcd, tcn_date, spl_clm_indctr, discharge_date,
                            procedure_iid, revenue_iid, diagnosis_iid, medicare_parta_deductible_amt,
                            medicare_partb_deductible_amt, invoice_type_lkpcd, mnl_price_indctr, medicare_indctr,
                            primary_pa_rqst_sid,
                             hdr_srvc_prvdr_lctn_identifier, -- Changes for MIPRO00053339
                             drg_code, --changes for MIPRO00050883
                             header_from_srvc_date, -- Changes for MIPRO00061738
                             header_to_srvc_date, --changes for MIPRO00061738
                             sbmtd_mdfr_code_1,sbmtd_mdfr_code_2,sbmtd_mdfr_code_3,sbmtd_mdfr_code_4   --changes for MIPRO00061214
                          )
                    VALUES (v_claim_header_sid, v_claim_line_sid, v_mbr_sid, v_from_service_date1, v_to_service_date1,
                            v_prcdr_code, v_mdfr_code1, v_mdfr_code2, v_mdfr_code3, v_mdfr_code4, v_trtmnt_type_code,
                            v_rac_code, v_paid_service_units, v_follow_up_days, v_payment_amount,
                            v_primary_diagnosis_code, v_spclty_code, v_subspclty_code, v_clm_type_cid,
                            v_clsfctn_group_cid, v_tooth_cid, v_surface_cid1, v_surface_cid2, v_surface_cid3,
                            v_surface_cid4, v_surface_cid5, v_sbmt_fclty_bill_clsfctn_sid,
                            v_clm_submission_reason_lkpcd, v_facility_type_code, v_bi_prvdr_lctn_idntfr,
                            v_bi_prvdr_type_code, 
                            -- Start changes for MIPRO00049929
                            CASE WHEN v_invoice_type_lkpcd ='P' AND  v_facility_type_code='24'
                            AND v_spclty_code='B364' AND v_subspclty_code='C999'
                            THEN  v_bi_prvdr_lctn_idntfr
                            ELSE
                            v_se_prvdr_lctn_idntfr
                            END 
                        -- End changes for MIPRO00049929
                            , v_procedure_pccm_indicator,
                            'A', v_quadrant_cid1, v_quadrant_cid2, v_quadrant_cid3, v_quadrant_cid4, v_revenue_code,
                            v_clm_ln_copay_amount, v_pa_rqst_sid1, v_pa_utilised_amount1, v_pa_utilised_units1,
                            v_pa_rqst_sid2, v_pa_utilised_amount2, v_pa_utilised_units2, p_created_by, SYSDATE,
                            v_billed_amount, v_admit_date, v_lo_reference_identification,
                            v_ld_reference_identification, v_pa_rqst_prcdr_sid1, v_pa_rqst_prcdr_sid2, v_txnmy_code,
                            v_quadrant_cid5, v_patient_status_lkpcd, v_tcn_date, v_spl_clm_indctr, v_discharge_dt,
                            v_proc_iid, v_revenue_iid, v_diagnosis_iid, v_mdcr_parta_deductible_amt,
                            v_mdcr_partb_deductible_amt, v_invoice_type_lkpcd, v_mnl_price_flag, v_medicare_flag,
                            v_primary_pa_rqst_sid,
                            v_hdr_srvcng_lctn_identifier, -- Changes for MIPRO00053339
                            v_drg_code,--changes for MIPRO00050883
                            v_hdr_from_serv_date,-- Changes for MIPRO00061738
                            v_hdr_to_serv_date, -- Changes for MIPRO00061738
                            v_sbmtd_mdfr_code1,v_sbmtd_mdfr_code2,v_sbmtd_mdfr_code3,v_sbmtd_mdfr_code4   --changes for MIPRO00061214
                           );
            END IF;   

            --Assign out parameters
            p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;  --vers Cloud RE 1.0.1
            p_err_msg := 'Successful....';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_err_code := '1';
               p_err_msg := 'No data found....';

               --Insert error log
               INSERT INTO tmp_mbr_clm_hist_status
                           (claim_header_sid, mbr_sid, status_cid, excptn_detail, date_time
                           )
                    VALUES (p_claim_header_sid, v_mbr_sid, 2, SUBSTR (p_err_msg, 1, 250), SYSDATE
                           );
         END;
      END LOOP;

      COMMIT;

      --Close cursor
      CLOSE cr_mbrpaidclaim;

      --Insert success into clm hist status
      INSERT INTO tmp_mbr_clm_hist_status
                  (claim_header_sid, mbr_sid, status_cid, excptn_detail, date_time
                  )
           VALUES (p_claim_header_sid, v_mbr_sid, 1, 'Successful', SYSDATE
                  );

      COMMIT;
   EXCEPTION
      WHEN e_getelement_excep THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg := SUBSTR ('Error executing Pr_GetClmDataElement: ' || p_err_msg, 1, 200);
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg :=
                'Error FOUND IN pr_InsMbrHistory....' || SUBSTR (SQLERRM, 1, 200)
                || DBMS_UTILITY.format_error_backtrace;

         --Insert error log
         INSERT INTO tmp_mbr_clm_hist_status
                     (claim_header_sid, mbr_sid, status_cid, excptn_detail, date_time
                     )
              VALUES (p_claim_header_sid, v_mbr_sid, 2, SUBSTR (p_err_msg, 1, 250), SYSDATE
                     );

         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code)
            ||'-'||SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_claim_header_sid,
                             NULL,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'pr_InsMbrHistory',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             p_created_by,
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_insmbrhistory;

----------------------------------------------------------------------------------------------------
   PROCEDURE pr_chkprcdrlimit (
      p_claim_header_sid     IN       NUMBER,
      p_hdr_srvc_from_date   IN       DATE,
      p_hdr_srvc_to_date     IN       DATE,
      p_year                 IN       VARCHAR2,
      p_created_by           IN       NUMBER,
      p_from_date            OUT      DATE,
      p_to_date              OUT      DATE,
      p_life_time_flag       OUT      VARCHAR2,
      p_err_code             OUT      VARCHAR2,
      p_err_msg              OUT      VARCHAR2
   )
   IS
      v_limit_sid        LIMIT.limit_sid%TYPE;
      v_from_date        DATE;
      v_to_date          DATE;
      v_from_date_str    VARCHAR2 (10);
      v_to_date_str      VARCHAR2 (10);
      v_from_date_temp   DATE;
      v_to_date_temp     DATE;
      v_life_time_flag   VARCHAR2 (1)           := 'N';
      v_errlog_code      VARCHAR2 (10);
      v_errlog_msg       VARCHAR2 (500);
      v_parameter_list   VARCHAR2 (2000);

      CURSOR cr_claimprcdrlimit (
         p_claim_header_sid     IN   claim_header.claim_header_sid%TYPE,
         p_hdr_srvc_from_date   IN   DATE,
         p_hdr_srvc_to_date     IN   DATE
      )
      IS
         SELECT   cl.procedure_iid, lg.limit_sid, cl.claim_line_sid
             FROM claim_header ch, claim_line cl, procedure_x_group pg, GROUPS g, limit_x_group lg, limit_status ls
            WHERE ch.claim_header_sid = p_claim_header_sid
              AND ch.claim_header_sid = cl.claim_header_sid
              AND pg.procedure_iid = cl.procedure_iid
              AND pg.status_cid = 2
              AND pg.oprtnl_flag = 'A'
              AND pg.from_date <= p_hdr_srvc_from_date
              AND pg.TO_DATE >= p_hdr_srvc_to_date
              AND pg.group_cid = g.group_cid
              AND (g.group_cid = lg.group_cid OR g.super_group_cid = lg.group_cid)
              AND lg.status_cid = 2
              AND lg.oprtnl_flag = 'A'
              AND lg.from_date <= p_hdr_srvc_from_date
              AND lg.TO_DATE >= p_hdr_srvc_to_date
              AND lg.limit_sid = ls.limit_sid
              AND ls.status_cid = 2
              AND ls.oprtnl_flag = 'A'
              AND ls.from_date <= p_hdr_srvc_from_date
              AND ls.TO_DATE >= p_hdr_srvc_to_date
         ORDER BY lg.limit_sid, cl.claim_line_sid;
   BEGIN
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, ''));
      v_parameter_list :=
                         v_parameter_list || '&' || 'p_hdr_srvc_from_date=' || TO_CHAR (NVL (p_hdr_srvc_from_date, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_hdr_srvc_to_date=' || TO_CHAR (NVL (p_hdr_srvc_to_date, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_year=' || TO_CHAR (NVL (p_year, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_created_by=' || TO_CHAR (NVL (p_created_by, ''));
      v_limit_sid := 0;

      FOR crec1 IN cr_claimprcdrlimit (p_claim_header_sid, p_hdr_srvc_from_date, p_hdr_srvc_to_date) LOOP
         BEGIN
            IF (v_limit_sid <> crec1.limit_sid) THEN
               v_limit_sid := crec1.limit_sid;
               /*Call procedure to get limit date range*/
               pk_limit.pr_getlimitdaterange (p_claim_header_sid,
                                              NULL,
                                              crec1.limit_sid,
                                              TO_CHAR (p_hdr_srvc_from_date, 'mm/dd/yyyy'),
                                              TO_CHAR (p_hdr_srvc_to_date, 'mm/dd/yyyy'),
                                              p_year,
                                              v_from_date_str,
                                              v_to_date_str,
                                              v_life_time_flag,
                                              p_err_code,
                                              p_err_msg
                                             );
               v_from_date := TO_DATE (v_from_date_str, 'mm/dd/yyyy');
               v_to_date := TO_DATE (v_to_date_str, 'mm/dd/yyyy');
            END IF;

            /*Derive temp from date*/
            IF ((v_from_date_temp IS NULL) OR (v_from_date < v_from_date_temp)) THEN
               v_from_date_temp := v_from_date;
            END IF;

            /*Derive temp to date*/
            IF ((v_to_date_temp IS NULL) OR (v_to_date > v_to_date_temp)) THEN
               v_to_date_temp := v_to_date;
            END IF;

            --Assign values to null
            v_from_date := NULL;
            v_to_date := NULL;

            --Check life time flag
            IF v_life_time_flag = 'Y' THEN
               --Assign value
               p_life_time_flag := v_life_time_flag;
               --Process each line of the claim
               pr_updclmhdrlnindicator_wip (p_claim_header_sid,
                                            crec1.claim_line_sid,
                                            p_created_by,
                                            p_err_code,
                                            p_err_msg
                                           );
            END IF;
         END;
      END LOOP;

      --Assign out parameters
      p_from_date := v_from_date_temp;
      p_to_date := v_to_date_temp;
      --Assign success to error codes
      p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;      --vers Cloud RE 1.0.1
      p_err_msg := 'Successful'; 
   EXCEPTION
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg := 'Error FOUND IN pr_ChkPrcdrLimit....' || SUBSTR (SQLERRM, 1, 200);
         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code)
                            ||'-'||SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_claim_header_sid,
                             NULL,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'pr_ChkPrcdrLimit',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             '1',
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_chkprcdrlimit;

----------------------------------------------------------------------------------------------------
   PROCEDURE pr_updclmhdrlnindicator_wip (
      p_claim_header_sid   IN       NUMBER,
      p_claim_line_sid     IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   )
   IS
      v_errlog_code      VARCHAR2 (10);
      v_errlog_msg       VARCHAR2 (500);
      v_parameter_list   VARCHAR2 (2000);
   BEGIN
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_claim_line_sid=' || TO_CHAR (NVL (p_claim_line_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_created_by=' || TO_CHAR (NVL (p_created_by, ''));

      UPDATE clm_hdr_x_indicator
         SET indctr_option_code = 'Y'
       WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = 136;

      /*Check if there are any records affected by update*/
      IF SQL%NOTFOUND THEN
         --Insert data for life time service indicator
         INSERT INTO clm_hdr_x_indicator
                     (clm_hdr_x_indicator_sid, claim_header_sid, indctr_type_cid, indctr_option_code, derived_qlfr,
                      created_by, created_date, modified_by, modified_date
                     )
              VALUES (clm_hdr_x_indicator_seq.NEXTVAL, p_claim_header_sid, 136,   --LIFETIME SERVICE INDICATOR
                                                                               'Y', 'D',
                      p_created_by, SYSDATE, p_created_by, SYSDATE
                     );
      END IF;

      -- Modified by Vijayakumar
      UPDATE clm_ln_x_indicator
         SET indctr_option_code = 'Y'
       WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = 136;

      /*Check if there are any records affected by update*/
      IF SQL%NOTFOUND THEN
         --Insert data for life time service indicator
         INSERT INTO clm_ln_x_indicator
                     (clm_ln_x_indicator_sid, claim_line_sid, indctr_type_cid, indctr_option_code, derived_qlfr,
                      created_by, created_date, modified_by, modified_date
                     )
              VALUES (clm_ln_x_indicator_seq.NEXTVAL, p_claim_line_sid, 136,   --LIFETIME SERVICE INDICATOR
                                                                            'Y', 'D',
                      p_created_by, SYSDATE, p_created_by, SYSDATE
                     );
      END IF;

      /*Assign success error code*/
      p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;      --vers Cloud RE 1.0.1
      p_err_msg := 'Successful Updation';
   EXCEPTION
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg := 'Error FOUND IN pr_UpdClmHdrLnIndicator_wip....' || SUBSTR (SQLERRM, 1, 200);
         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code) 
                            ||'-'||SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_claim_header_sid,
                             p_claim_line_sid,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'pr_UpdClmHdrLnIndicator',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             '1',
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_updclmhdrlnindicator_wip;

----------------------------------------------------------------------------------------------------
   PROCEDURE pr_getclmdataelement (
      p_claim_header_sid              IN       ad_claim_header.claim_header_sid%TYPE,
      p_claim_line_sid                IN       ad_claim_line.claim_line_sid%TYPE,
      p_from_service_dt               IN       ad_claim_header.from_service_date%TYPE,
      p_to_service_dt                 IN       ad_claim_header.to_service_date%TYPE,
      p_pa_request_from_dt            IN       ad_claim_header.from_service_date%TYPE,
      p_pa_request_to_dt              IN       ad_claim_header.to_service_date%TYPE,
      p_old_claim_header_sid          IN       claim_header.claim_header_sid%TYPE,
      p_clm_submission_reason_lkpcd   OUT      ad_claim_header.claim_submission_reason_lkpcd%TYPE,
      p_copay_amount                  OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_payment_amount                OUT      clm_ln_payment_info.payment_amount%TYPE,
      p_paid_service_units            OUT      clm_ln_payment_info.paid_service_units%TYPE,
      p_rac_code                      OUT      ad_clm_ln_derived_element.rac_code%TYPE,
      p_clm_type_cid                  OUT      ad_claim_line.clm_type_cid%TYPE,
      p_trtmnt_type_code              OUT      ad_clm_ln_derived_element.blng_prvdr_trtmnt_type_code%TYPE,
      p_clsfctn_group_cid             OUT      ad_claim_line.clsfctn_group_cid%TYPE,
      p_procedure_iid                 OUT      ad_claim_line.procedure_iid%TYPE,
      p_follow_up_days                OUT      procedure_detail.follow_up_days%TYPE,
      p_prcdr_code                    OUT      VARCHAR2,
      p_revenue_iid                   OUT      ad_claim_line.revenue_iid%TYPE,
      p_revenue_code                  OUT      VARCHAR2,
      p_bi_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_bi_prvdr_type_code            OUT      VARCHAR2,
      p_spclty_code                   OUT      specialty_subspecialty.spclty_code%TYPE,
      p_subspclty_code                OUT      specialty_subspecialty.subspclty_code%TYPE,
      p_proc_pccm_indctor             OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_se_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_mdcr_parta_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_parta_deductible_amt%TYPE,
      p_mdcr_partb_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_partb_deductible_amt%TYPE,
      p_primary_diag_code             OUT      VARCHAR2,
      p_tooth_cid                     OUT      ad_clm_ln_dental_detail.tooth_cid%TYPE,
      p_mdfr_code1                    OUT      ad_claim_line.mdfr_code1%TYPE,
      p_mdfr_code2                    OUT      ad_claim_line.mdfr_code2%TYPE,
      p_mdfr_code3                    OUT      ad_claim_line.mdfr_code3%TYPE,
      p_mdfr_code4                    OUT      ad_claim_line.mdfr_code4%TYPE,
      p_surface_cid1                  OUT      ad_clm_ln_dental_detail.surface1_cid%TYPE,
      p_surface_cid2                  OUT      ad_clm_ln_dental_detail.surface2_cid%TYPE,
      p_surface_cid3                  OUT      ad_clm_ln_dental_detail.surface3_cid%TYPE,
      p_surface_cid4                  OUT      ad_clm_ln_dental_detail.surface4_cid%TYPE,
      p_surface_cid5                  OUT      ad_clm_ln_dental_detail.surface5_cid%TYPE,
      p_quadrant_cid1                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn1_cid%TYPE,
      p_quadrant_cid2                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn2_cid%TYPE,
      p_quadrant_cid3                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn3_cid%TYPE,
      p_quadrant_cid4                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn4_cid%TYPE,
      p_pa_utilised_amount1           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units1            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid1                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_pa_utilised_amount2           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units2            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid2                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_lo_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_ld_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_billed_amount                 OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_pa_rqst_prcdr_sid1            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_pa_rqst_prcdr_sid2            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_txnmy_code                    OUT      ad_clm_ln_derived_element.txnmy_code%TYPE,
      p_quadrant_cid5                 OUT      ad_clm_ln_oral_cvty_dsgntn_dtl.oral_cavity_dsgntn5_cid%TYPE,
      p_patient_status_lkpcd          OUT      ad_clm_hdr_admission_detail.patient_status_lkpcd%TYPE,
      p_spl_clm_indctr                OUT      ad_clm_hdr_x_indicator.indctr_option_code%TYPE,
      p_allowed_amount                OUT      NUMBER,
      p_oth_pyr_paid_amount           OUT      NUMBER,
      p_high_risk_ob_care_enh_amt     OUT      NUMBER,
      p_mnl_price_flag                OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_medicare_flag                 OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_hdr_srvcng_lctn_identifier    OUT      prvdr_lctn_identifier.idntfr%TYPE,-- Changes for MIPRO00053339
      p_drg_code                      OUT      ad_claim_header.drg_code%TYPE,--changes for MIPRO00050883
      p_sbmtd_mdfr_code1              OUT      ad_claim_line.mdfr_code1%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code2              OUT      ad_claim_line.mdfr_code2%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code3              OUT      ad_claim_line.mdfr_code3%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code4              OUT      ad_claim_line.mdfr_code4%TYPE, --Changes for MIPRO00061214
      p_err_code                      OUT      VARCHAR2,
      p_err_msg                       OUT      VARCHAR2
   )
   IS
      --
      v_prvdr_lctn_iid              ad_clm_hdr_x_prvdr_lctn.prvdr_lctn_iid%TYPE;
      v_blng_spclty_subspclty_sid   ad_clm_ln_derived_element.blng_spclty_subspclty_sid%TYPE;
      v_pa_utilised_amount          pa_rqst_prcdr_utilization.prcdr_amount%TYPE                := 0;
      v_srvcng_prvdr_lctn_iid       ad_claim_header.srvcng_prvdr_lctn_iid%TYPE;
      v_pa_utilised_units           pa_rqst_prcdr_utilization.prcdr_units%TYPE                 := 0;
      v_cnt                         NUMBER                                                     := 0;
      v_from_service_date           VARCHAR2 (10);
      v_to_service_date             VARCHAR2 (10);
      v_errlog_code                 VARCHAR2 (10);
      v_errlog_msg                  VARCHAR2 (500);
      v_parameter_list              VARCHAR2 (2000);
      v_lo_ref_idntfcn_1            ad_clm_hdr_reference_info.reference_identification%TYPE;
      v_ld_ref_idntfcn_1            ad_clm_hdr_reference_info.reference_identification%TYPE;
      v_pa_rqst_prcdr_sid           pa_request_procedure.pa_rqst_prcdr_sid%TYPE;
      v_min_claim_line_sid          ad_claim_line.claim_line_sid%TYPE;

      CURSOR c_parqst (
         p_claim_header_sid   IN   ad_claim_line.claim_header_sid%TYPE,
         p_claim_line_sid     IN   ad_claim_line.claim_line_sid%TYPE
      )
      IS
         SELECT *
           FROM ad_clm_ln_x_pa_rqst
          WHERE claim_line_sid = p_claim_line_sid;
   --
   BEGIN
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_claim_line_sid=' || TO_CHAR (NVL (p_claim_line_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_from_service_dt=' || TO_CHAR (NVL (p_from_service_dt, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_to_service_dt=' || TO_CHAR (NVL (p_to_service_dt, ''));
      v_parameter_list :=
                         v_parameter_list || '&' || 'p_pa_request_from_dt=' || TO_CHAR (NVL (p_pa_request_from_dt, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_pa_request_to_dt=' || TO_CHAR (NVL (p_pa_request_to_dt, ''));
      v_parameter_list :=
                     v_parameter_list || '&' || 'p_old_claim_header_sid=' || TO_CHAR (NVL (p_old_claim_header_sid, ''));

      BEGIN
         SELECT patient_status_lkpcd
           INTO p_patient_status_lkpcd
           FROM ad_clm_hdr_admission_detail
          WHERE claim_header_sid = p_claim_header_sid;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_patient_status_lkpcd := NULL;
      END;

      BEGIN
         SELECT indctr_option_code
           INTO p_spl_clm_indctr
           FROM ad_clm_ln_x_indicator
          WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = gc_indctr_type_cid;
      -- Version 1.7 (Made into Function to execute once and assign Globally)...
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            BEGIN
               SELECT indctr_option_code
                 INTO p_spl_clm_indctr
                 FROM ad_clm_hdr_x_indicator
                WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = gc_indctr_type_cid;
            -- Version 1.7 (Made into Function to execute once and assign Globally)...
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  p_spl_clm_indctr := NULL;
            END;
      END;

      /*Get payment details for line*/
      BEGIN
         --Bharathy changed the claim type and classification to claim line derived element
         SELECT cld.rac_code, cld.clm_type_cid, cld.blng_prvdr_trtmnt_type_code,   --Rev1.15
                                                                                cld.clsfctn_group_cid,
                TO_CHAR (cl.from_service_date, 'MM/DD/YYYY'), TO_CHAR (cl.to_service_date, 'MM/DD/YYYY'),
                NVL (cl.srvcng_prvdr_lctn_iid, 0), NVL (cld.blng_spclty_subspclty_sid, 0), NVL (cld.paid_amount, 0),
                NVL (cld.paid_srvc_units, 0), cld.txnmy_code, fn_iidtorefcode (cl.primary_diagnosis_iid),
                cld.copay_amount, cl.mdfr_code1, cl.mdfr_code2, cl.mdfr_code3, cl.mdfr_code4, cl.billed_amount,
                cl.procedure_iid, cl.prcdr_code, cl.revenue_iid, cl.revenue_code, 
                NVL(cld.drvd_srvcng_prvdr_lctn_iid, cl.srvcng_prvdr_lctn_iid),--modified as per CQ#52349
                cld.medicare_parta_deductible_amt, cld.medicare_partb_deductible_amt,
                cl.sbmtd_mdfr_code_1,cl.sbmtd_mdfr_code_2,cl.sbmtd_mdfr_code_3,cl.sbmtd_mdfr_code_4   --changes for MIPRO00061214
           INTO p_rac_code, p_clm_type_cid, p_trtmnt_type_code, p_clsfctn_group_cid,
                v_from_service_date, v_to_service_date,
                v_prvdr_lctn_iid, v_blng_spclty_subspclty_sid, p_payment_amount,
                p_paid_service_units, p_txnmy_code, p_primary_diag_code,
                p_copay_amount, p_mdfr_code1, p_mdfr_code2, p_mdfr_code3, p_mdfr_code4, p_billed_amount,
                p_procedure_iid, p_prcdr_code, p_revenue_iid, p_revenue_code, p_se_prvdr_lctn_idntfr,
                p_mdcr_parta_deductible_amt, p_mdcr_partb_deductible_amt,
                p_sbmtd_mdfr_code1,p_sbmtd_mdfr_code2,p_sbmtd_mdfr_code3,p_sbmtd_mdfr_code4   --changes for MIPRO00061214
           FROM ad_clm_ln_derived_element cld, ad_claim_line cl
          WHERE cl.claim_line_sid = p_claim_line_sid AND cl.claim_line_sid = cld.claim_line_sid(+);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_rac_code := NULL;
            p_clm_type_cid := NULL;
            p_trtmnt_type_code := NULL;
            p_clsfctn_group_cid := NULL;
            p_payment_amount := NULL;
            p_paid_service_units := NULL;
            p_txnmy_code := NULL;
            p_primary_diag_code := NULL;
            p_copay_amount := NULL;
            p_mdfr_code1 := NULL;
            p_mdfr_code2 := NULL;
            p_mdfr_code3 := NULL;
            p_mdfr_code4 := NULL;
            p_billed_amount := NULL;
            p_procedure_iid := NULL;
            p_revenue_iid := NULL;
            p_prcdr_code := NULL;
            p_revenue_code := NULL;
            p_se_prvdr_lctn_idntfr := NULL;
            p_mdcr_parta_deductible_amt := NULL;
            p_mdcr_partb_deductible_amt := NULL;
            p_sbmtd_mdfr_code1 := NULL;
            p_sbmtd_mdfr_code2 := NULL;
            p_sbmtd_mdfr_code3 := NULL;
            p_sbmtd_mdfr_code4 := NULL;
      END;

      BEGIN
         SELECT indctr_option_code
           INTO p_medicare_flag
           FROM ad_clm_hdr_x_indicator
          WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = 737 AND ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_medicare_flag := NULL;
      END;

      IF NVL (p_clm_type_cid, -99) = 2 THEN
         BEGIN
            SELECT indctr_option_code
              INTO p_mnl_price_flag
              FROM ad_clm_hdr_x_indicator
             WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = 140 AND ROWNUM = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mnl_price_flag := NULL;
         END;
      ELSE
         BEGIN
            SELECT indctr_option_code
              INTO p_mnl_price_flag
              FROM ad_clm_ln_x_indicator
             WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = 140 AND ROWNUM = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mnl_price_flag := NULL;
         END;
      END IF;     


      /*Get procedure iid*/
      BEGIN
         SELECT pd.follow_up_days
           INTO p_follow_up_days
           FROM procedure_detail pd, procedure_status ps
          WHERE pd.procedure_iid = NVL (p_procedure_iid, p_revenue_iid)
            AND pd.procedure_iid = ps.procedure_iid
            AND pd.prcdr_dtl_sid = ps.prcdr_dtl_sid
            AND ps.status_type_cid = 1
            AND ps.status_cid = 2
            AND ps.oprtnl_flag = 'A'
            AND fn_getanchordt (p_from_service_dt, p_to_service_dt) BETWEEN ps.from_date AND ps.TO_DATE;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_follow_up_days := NULL;
      END;

      BEGIN
         SELECT blng_prvdr_lctn_iid, blng_prvdr_type_code, claim_submission_reason_lkpcd, 
                NVL(chde.drvd_srvcng_prvdr_lctn_iid,ch.srvcng_prvdr_lctn_iid),--Changed as per MIPRO00052349
                (SELECT MIN (claim_line_sid)
                   FROM ad_claim_line
                  WHERE claim_header_sid = ch.claim_header_sid) min_claim_line_sid
           INTO p_bi_prvdr_lctn_idntfr, p_bi_prvdr_type_code, p_clm_submission_reason_lkpcd, v_srvcng_prvdr_lctn_iid,
                v_min_claim_line_sid
           FROM ad_claim_header ch,
                ad_clm_hdr_derived_element chde --Added as per CQ#52349
          WHERE ch.claim_header_sid = p_claim_header_sid
            AND chde.claim_header_sid=ch.claim_header_sid ;--Added as per CQ#52349

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_bi_prvdr_type_code := NULL;
            p_bi_prvdr_lctn_idntfr := NULL;
            p_clm_submission_reason_lkpcd := NULL;
            v_srvcng_prvdr_lctn_iid := NULL;
      END;

      p_se_prvdr_lctn_idntfr := NVL (p_se_prvdr_lctn_idntfr, v_srvcng_prvdr_lctn_iid);

      p_hdr_srvcng_lctn_identifier := v_srvcng_prvdr_lctn_iid; -- Changes for MIPRO00053339

      IF v_blng_spclty_subspclty_sid <> 0 THEN
         --Get spclty, subspclty code
         SELECT ssp.spclty_code, ssp.subspclty_code
           INTO p_spclty_code, p_subspclty_code
           FROM specialty_subspecialty ssp
          WHERE ssp.spclty_subspclty_sid = v_blng_spclty_subspclty_sid AND ssp.oprtnl_flag = 'A';
      END IF;

      /*Get indicator option*/
      BEGIN
         SELECT indctr_option_code
           INTO p_proc_pccm_indctor
           FROM ad_clm_ln_x_indicator
          WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = 137 AND indctr_option_code = 'Y';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_proc_pccm_indctor := NULL;
      END;


      /*Initailize count*/
      v_cnt := 1;

      /*Derive tooth,surface cid*/
      BEGIN
         SELECT surface1_cid, surface2_cid, surface3_cid, surface4_cid, tooth_cid
           INTO p_surface_cid1, p_surface_cid2, p_surface_cid3, p_surface_cid4, p_tooth_cid
           FROM ad_clm_ln_dental_detail
          WHERE clm_ln_dental_detail_sid=
                (SELECT   MIN (clm_ln_dental_detail_sid)
                       FROM   ad_clm_ln_dental_detail k
                      WHERE   k.claim_line_sid = p_claim_line_sid);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_surface_cid1 := NULL;
            p_surface_cid2 := NULL;
            p_surface_cid3 := NULL;
            p_surface_cid4 := NULL;
            p_tooth_cid := NULL;
      END;

      /*Initailize count*/
      v_cnt := 1;

      BEGIN
         SELECT oral_cavity_dsgntn1_cid, oral_cavity_dsgntn2_cid, oral_cavity_dsgntn3_cid, oral_cavity_dsgntn4_cid,
                oral_cavity_dsgntn5_cid
           INTO p_quadrant_cid1, p_quadrant_cid2, p_quadrant_cid3, p_quadrant_cid4,
                p_quadrant_cid5
           FROM ad_clm_ln_oral_cvty_dsgntn_dtl   -- should be ad table
          WHERE claim_line_sid = p_claim_line_sid;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_quadrant_cid1 := NULL;
            p_quadrant_cid2 := NULL;
            p_quadrant_cid3 := NULL;
            p_quadrant_cid4 := NULL;
            p_quadrant_cid5 := NULL;
      END;

      /*Initialize count*/
      v_cnt := 0;

      /*Process cursor for pa requests*/
      FOR parqst_rec IN c_parqst (p_claim_header_sid, p_claim_line_sid) LOOP
         /*Increment the count*/
         v_cnt := (v_cnt + 1);

         /*Get utilised units, amount*/
         BEGIN
            SELECT   SUM (NVL (pu.prcdr_amount, 0)), SUM (NVL (pu.prcdr_units, 0)), pp.pa_rqst_prcdr_sid
                INTO v_pa_utilised_amount, v_pa_utilised_units, v_pa_rqst_prcdr_sid
                FROM pa_request_service prs, pa_request_procedure pp, pa_rqst_prcdr_utilization pu
               WHERE prs.pa_rqst_sid = parqst_rec.pa_rqst_sid
                 AND prs.oprtnl_flag = 'A'
                 AND prs.pa_rqst_srvc_sid = pp.pa_rqst_srvc_sid
                 AND pp.procedure_iid = p_procedure_iid
                 AND pp.oprtnl_flag = 'A'
                 AND pp.status_cid = 20
                 AND pp.pa_rqst_prcdr_sid = pu.pa_rqst_prcdr_sid
                 AND pu.oprtnl_flag = 'A'
                 AND pu.from_date <= p_pa_request_from_dt
                 AND pu.TO_DATE >= p_pa_request_to_dt
            GROUP BY pp.pa_rqst_prcdr_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_pa_utilised_amount := NULL;
               v_pa_utilised_units := NULL;
               v_pa_rqst_prcdr_sid := NULL;
         END;

         /*Check whether this has to be assigned to 1 or 2*/
         IF v_cnt = 1 THEN
            p_pa_utilised_amount1 := v_pa_utilised_amount;
            p_pa_utilised_units1 := v_pa_utilised_units;
            p_pa_rqst_sid1 := parqst_rec.pa_rqst_sid;
            p_pa_rqst_prcdr_sid1 := v_pa_rqst_prcdr_sid;
         ELSIF v_cnt = 2 THEN
            p_pa_utilised_amount2 := v_pa_utilised_amount;
            p_pa_utilised_units2 := v_pa_utilised_units;
            p_pa_rqst_sid2 := parqst_rec.pa_rqst_sid;
            p_pa_rqst_prcdr_sid2 := v_pa_rqst_prcdr_sid;
         END IF;
      END LOOP;

      /*Get origin code*/
      BEGIN
         -- Merged both into ONE statement using DECODE version 1.7
         SELECT DECODE (reference_info_lkpcd, 'LO', reference_identification, NULL),
                DECODE (reference_info_lkpcd, 'LD', reference_identification, NULL)
           INTO v_lo_ref_idntfcn_1,
                v_ld_ref_idntfcn_1
           FROM ad_clm_ln_reference_info
          WHERE claim_line_sid = p_claim_line_sid;

         p_lo_ref_idntfcn := v_lo_ref_idntfcn_1;
         p_ld_ref_idntfcn := v_ld_ref_idntfcn_1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_lo_ref_idntfcn := NULL;
            p_ld_ref_idntfcn := NULL;
         WHEN TOO_MANY_ROWS THEN
            BEGIN
               SELECT reference_identification
                 INTO v_lo_ref_idntfcn_1
                 FROM ad_clm_ln_reference_info
                WHERE claim_line_sid = p_claim_line_sid AND reference_info_lkpcd = 'LO';
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_lo_ref_idntfcn_1 := NULL;
            END;

            BEGIN
               SELECT reference_identification
                 INTO v_ld_ref_idntfcn_1
                 FROM ad_clm_ln_reference_info
                WHERE claim_line_sid = p_claim_line_sid AND reference_info_lkpcd = 'LD';
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_ld_ref_idntfcn_1 := NULL;
            END;
      END;

      IF p_clm_type_cid = 2 AND p_claim_line_sid = v_min_claim_line_sid THEN
         BEGIN
            SELECT medicare_parta_deductible_amt, medicare_partb_deductible_amt
              INTO p_mdcr_parta_deductible_amt, p_mdcr_partb_deductible_amt
              FROM ad_clm_hdr_derived_element
             WHERE claim_header_sid = p_claim_header_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mdcr_parta_deductible_amt := NULL;
               p_mdcr_partb_deductible_amt := NULL;
         END;
      END IF;

   /* Get DRG CODE */   
      IF p_clm_type_cid = 2  THEN
         BEGIN
            SELECT NVL(achde.drg_code,ach.drg_code)
              INTO p_drg_code
              FROM ad_clm_hdr_derived_element achde ,ad_claim_header ach
             WHERE ach.claim_header_sid = p_claim_header_sid
               AND ach.claim_header_sid=achde.claim_header_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_drg_code := NULL;
         END;
      END IF;
   /* Get DRG CODE */   

      /*Successful*/
      p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;      --vers Cloud RE 1.0.1
      p_err_msg := 'Successful...';
   EXCEPTION
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg := SUBSTR (SQLERRM, 1, 200) || DBMS_UTILITY.format_error_backtrace;
         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code)
                            ||'-'||SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_old_claim_header_sid,
                             NULL,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'Pr_GetClmDataElement',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             '1',
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_getclmdataelement;
      PROCEDURE pr_ins_enc_mbrhistory (
      p_claim_header_sid   IN       NUMBER,
      p_created_by         IN       NUMBER,
      p_err_code           OUT      VARCHAR2,
      p_err_msg            OUT      VARCHAR2
   )
   IS
        v_clm_source_code                         claim_header.clm_source_code%TYPE;
        v_claim_header_sid                      tmp_mbr_enc_history.claim_header_sid%TYPE;
        v_claim_line_sid                        tmp_mbr_enc_history.claim_line_sid%TYPE;
        v_mbr_sid                               tmp_mbr_enc_history.mbr_sid%TYPE;
        v_hdr_from_service_date                 tmp_mbr_enc_history.hdr_from_service_date%TYPE;
        v_hdr_to_service_date                   tmp_mbr_enc_history.hdr_to_service_date%TYPE;
        v_ln_from_service_date                  tmp_mbr_enc_history.ln_from_service_date%TYPE;
        v_ln_to_service_date                    tmp_mbr_enc_history.ln_to_service_date%TYPE;
        v_procedure_iid                         tmp_mbr_enc_history.procedure_iid%TYPE;
        v_prcdr_code                            tmp_mbr_enc_history.prcdr_code%TYPE;
        v_mdfr_code1                            tmp_mbr_enc_history.mdfr_code1%TYPE;
        v_mdfr_code2                            tmp_mbr_enc_history.mdfr_code2%TYPE;
        v_mdfr_code3                            tmp_mbr_enc_history.mdfr_code3%TYPE;
        v_mdfr_code4                            tmp_mbr_enc_history.mdfr_code4%TYPE;
        v_revenue_iid                           tmp_mbr_enc_history.revenue_iid%TYPE;
        v_revenue_code                          tmp_mbr_enc_history.revenue_code%TYPE;
        v_clm_type_cid                          tmp_mbr_enc_history.clm_type_cid%TYPE;
        v_tooth_cid                             tmp_mbr_enc_history.tooth_cid%TYPE;
        v_op_hp_prvdr_lctn_mmis_idntfr          tmp_mbr_enc_history.op_hp_prvdr_lctn_mmis_idntfr%TYPE;
        v_blng_prvdr_lctn_iid                   tmp_mbr_enc_history.blng_prvdr_lctn_iid%TYPE;
        v_bi_prvdr_lctn_idntfr                  tmp_mbr_enc_history.billing_prvdr_lctn_identifier%TYPE;
        v_srvcng_prvdr_lctn_iid                 tmp_mbr_enc_history.srvcng_prvdr_lctn_iid%TYPE;
        v_srvc_prvdr_lctn_identifier            tmp_mbr_enc_history.service_prvdr_lctn_identifier%TYPE;
        v_attn_prvdr_lctn_iid                   tmp_mbr_enc_history.attn_prvdr_lctn_iid%TYPE;
        v_attn_prvdr_lctn_identifier            tmp_mbr_enc_history.attn_prvdr_lctn_identifier%TYPE;
        v_created_by                            tmp_mbr_enc_history.created_by%TYPE;
        v_created_date                          tmp_mbr_enc_history.created_date%TYPE;
        v_invoice_type_lkpcd                    tmp_mbr_enc_history.invoice_type_lkpcd%TYPE;
        v_claim_sbmsn_reason_lkpcd              tmp_mbr_enc_history.claim_submission_reason_lkpcd%TYPE;
        v_claim_line_tcn                        tmp_mbr_enc_history.claim_line_tcn%TYPE;
        v_parent_tcn                            ad_claim_header.parent_tcn%TYPE;
        v_ern                                   claim_header.ern%TYPE;    
        v_cnt                                     NUMBER (5)                                                    := 0;
        v_curr_clm_from_service_date    ad_claim_header.from_service_date%TYPE;
        v_curr_clm_to_service_date      ad_claim_header.to_service_date%TYPE;
        v_errlog_code                   VARCHAR2 (10);
        v_errlog_msg                    VARCHAR2 (500);
        v_old_claim_header_sid          ad_claim_header.claim_header_sid%TYPE;
        v_old_claim_line_sid            ad_claim_line.claim_line_sid%TYPE;
        v_cnt1                          NUMBER                                                        := 0;
        v_proceed_flag                  VARCHAR (1)                                                   := 'Y';
        v_cursor_cnt                    NUMBER                                                        := 0;
        v_parameter_list                VARCHAR2 (2000);
        v_clm_ln_copay_amt              NUMBER (15,2);--changes per CQ#62095
        v_orig_tcn                      ad_claim_header.original_tcn%Type;


     CURSOR cr_mbrenc (p_mbr_sid IN MEMBER.mbr_sid%TYPE, p_from_date_temp_dt IN DATE, p_to_date_temp_dt IN DATE,p_ern IN claim_header.ern%TYPE)
      IS
         SELECT        /*+ INDEX (ch XIF15AD_CLAIM_HEADER) INDEX(cl XIF26AD_CLAIM_LINE) */   
                cl.claim_header_sid, cl.claim_line_sid,
                            cl.claim_line_tcn,
                            ch.mbr_sid,
                          TRUNC(ch.from_service_date),
                          TRUNC(ch.to_service_date),
                         TRUNC (cl.from_service_date),
                         TRUNC (cl.to_service_date),
                         cl.procedure_iid,
                         cl.prcdr_code,
                        cl.mdfr_code1,
                        cl.mdfr_code2,
                        cl.mdfr_code3,
                        cl.mdfr_code4,
                        cl.revenue_iid,
                        cl.revenue_code,
                        ch.clm_type_cid,
                        (select tooth_cid from ad_clm_ln_dental_detail where claim_line_sid=cl.claim_line_sid and rownum=1),
                        ch.claim_submission_reason_lkpcd,
                        ch.op_hp_prvdr_lctn_mmis_idntfr,
                        ch.blng_prvdr_lctn_iid,
                        ch.blng_prvdr_lctn_identifier,
                        ch.srvcng_prvdr_lctn_iid,
                        ch.srvcng_prvdr_lctn_identifier,
                        (select prvdr_lctn_iid from ad_clm_hdr_x_prvdr_lctn
                            where clm_prvdr_type_lkpcd='AT'
                                and claim_header_sid=ch.claim_header_sid and rownum=1 ),     --V 1.25 MIPRO00096760
                        (select prvdr_lctn_identifier from ad_clm_hdr_x_prvdr_lctn           --V 1.25 MIPRO00096760
                            where clm_prvdr_type_lkpcd='AT'
                                and claim_header_sid=ch.claim_header_sid and rownum=1 ),
                        SYSDATE,
                        ch.invoice_type_lkpcd
                    FROM ad_claim_header ch, ad_claim_line cl
                   WHERE ch.mbr_sid = p_mbr_sid
                     AND ch.claim_header_sid = cl.claim_header_sid
                     AND cl.bsns_status_type_cid = 8
                     AND cl.bsns_status_cid = 83
                     AND ch.clm_enc_flag = 'ENC'   
                     AND ch.original_tcn<>v_orig_tcn 
                     AND (ch.ern IS NOT NULL AND ern <> p_ern)
                     AND ch.claim_submission_reason_lkpcd IN('1','7')
                     AND NVL (cl.from_service_date, ch.from_service_date) <= p_to_date_temp_dt
                     AND NVL (NVL (cl.to_service_date, cl.from_service_date),
                              NVL (ch.to_service_date, ch.from_service_date)
                             ) >= p_from_date_temp_dt;
   BEGIN
      p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;  --vers Cloud RE 1.0.1
      p_err_msg := 'Success';
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, 0));
      v_parameter_list := v_parameter_list || '&' || 'p_created_by=' || TO_CHAR (NVL (p_created_by, 0));

      --- Assigning Global Variable version 1.17....
      gc_indctr_type_cid := fn_getspecialclaimindctr;

      SELECT ch.from_service_date, ch.to_service_date,ch.claim_submission_reason_lkpcd, 
            ch.mbr_sid,ch.parent_tcn, clm_source_code,ern,original_tcn
        INTO  v_curr_clm_from_service_date,v_curr_clm_to_service_date,v_claim_sbmsn_reason_lkpcd,v_mbr_sid,
             v_parent_tcn,v_clm_source_code,v_ern,v_orig_tcn
        FROM claim_header ch   
       WHERE ch.claim_header_sid = p_claim_header_sid;

      /*Delete records from TMP_MBR_ENC_HISTORY for the member sid*/

         DELETE      TMP_MBR_ENC_HISTORY
               WHERE mbr_sid = v_mbr_sid;
      COMMIT;



      IF v_claim_sbmsn_reason_lkpcd IN ('7') THEN
         BEGIN
            SELECT claim_header_sid
              INTO v_old_claim_header_sid
              FROM ad_claim_header
             WHERE tcn = v_parent_tcn;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_old_claim_header_sid := NULL;
         END;
       END IF;

      --Process paid claim
      OPEN cr_mbrenc (v_mbr_sid, v_curr_clm_from_service_date, v_curr_clm_to_service_date,v_ern);

      /*Process for each record of the opened cursor*/
      LOOP
         BEGIN
            FETCH cr_mbrenc
             INTO   v_claim_header_sid,
                    v_claim_line_sid,
                    v_claim_line_tcn,
                    v_mbr_sid,
                    v_hdr_from_service_date,
                    v_hdr_to_service_date,
                    v_ln_from_service_date,
                    v_ln_to_service_date,
                    v_procedure_iid,
                    v_prcdr_code,
                    v_mdfr_code1,
                    v_mdfr_code2,
                    v_mdfr_code3,
                    v_mdfr_code4,
                    v_revenue_iid,
                    v_revenue_code,
                    v_clm_type_cid,
                    v_tooth_cid,
                    v_claim_sbmsn_reason_lkpcd,
                    v_op_hp_prvdr_lctn_mmis_idntfr,
                    v_blng_prvdr_lctn_iid,
                    v_bi_prvdr_lctn_idntfr,
                    v_srvcng_prvdr_lctn_iid,
                    v_srvc_prvdr_lctn_identifier,
                    v_attn_prvdr_lctn_iid,
                    v_attn_prvdr_lctn_identifier,
                    v_created_date,
                    v_invoice_type_lkpcd;

            EXIT WHEN cr_mbrenc%NOTFOUND;
            v_proceed_flag := 'Y';
            v_created_by := p_created_by;

            BEGIN   -- Rev 1.24 changes start
                   SELECT   'N'
                     INTO   v_proceed_flag
                     FROM   ad_claim_line
                    WHERE   claim_header_sid = v_old_claim_header_sid
                            AND claim_line_sid = v_claim_line_sid;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                      v_proceed_flag := 'Y';
            END;-- Rev 1.24 changes start

             --Changes for CQ#62095 Starts

               SELECT copay_amount
                 INTO v_clm_ln_copay_amt
                 FROM ad_clm_ln_derived_element 
                WHERE claim_line_sid = v_claim_line_sid;

             --Changes for CQ#62095 Ends  
             BEGIN   -- Rev 1.24 changes start
                   SELECT   'N'
                     INTO   v_proceed_flag
                     FROM   TMP_MBR_ENC_HISTORY
                    WHERE   claim_header_sid = v_claim_header_sid AND claim_line_sid = v_claim_line_sid;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                   NULL;
            END;-- Rev 1.24 changes start

            IF v_proceed_flag = 'Y' THEN
               --Insert into tmp mbr clm history
               INSERT INTO TMP_MBR_ENC_HISTORY
                           (claim_header_sid,claim_line_sid,claim_line_tcn,mbr_sid,hdr_from_service_date,hdr_to_service_date,
                            ln_from_service_date,ln_to_service_date,procedure_iid,prcdr_code,
                            mdfr_code1,mdfr_code2,mdfr_code3,mdfr_code4,revenue_iid,revenue_code,
                            clm_type_cid,tooth_cid,claim_submission_reason_lkpcd,op_hp_prvdr_lctn_mmis_idntfr,
                            blng_prvdr_lctn_iid,billing_prvdr_lctn_identifier,srvcng_prvdr_lctn_iid,
                            service_prvdr_lctn_identifier,attn_prvdr_lctn_iid,attn_prvdr_lctn_identifier,
                            created_by,created_date,invoice_type_lkpcd,
                            clm_ln_copay_amount--  changes as per CQ#62095
                           )
                    VALUES (v_claim_header_sid,v_claim_line_sid,v_claim_line_tcn,v_mbr_sid,v_hdr_from_service_date,v_hdr_to_service_date,
                            v_ln_from_service_date,v_ln_to_service_date,v_procedure_iid,v_prcdr_code,
                            v_mdfr_code1,v_mdfr_code2,v_mdfr_code3,v_mdfr_code4,v_revenue_iid,
                            v_revenue_code,v_clm_type_cid,v_tooth_cid,v_claim_sbmsn_reason_lkpcd,v_op_hp_prvdr_lctn_mmis_idntfr,
                            v_blng_prvdr_lctn_iid,v_bi_prvdr_lctn_idntfr,v_srvcng_prvdr_lctn_iid,
                            v_srvc_prvdr_lctn_identifier,v_attn_prvdr_lctn_iid,v_attn_prvdr_lctn_identifier,v_created_by,
                            v_created_date,v_invoice_type_lkpcd,
                            v_clm_ln_copay_amt --  changes as per CQ#62095
                           );
            END IF;   

            p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS; --vers Cloud RE 1.0.1
            p_err_msg := 'Successful....';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_err_code := '1';
               p_err_msg := 'No data found....';

         END;
      END LOOP;

      COMMIT;

      CLOSE cr_mbrenc;


      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg :=
                'Error FOUND IN pr_ins_enc_mbrhistory....' || SUBSTR (SQLERRM, 1, 200)
                || DBMS_UTILITY.format_error_backtrace;

         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code) 
                            ||'-'|| SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_claim_header_sid,
                             NULL,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'pr_ins_enc_mbrhistory',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             p_created_by,
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_ins_enc_mbrhistory;
-----------------------------------------------------------------------------------------------------
--Changes Starts for CQ#70112
procedure  pr_getclmdataelement_wip (
      p_claim_header_sid              IN       ad_claim_header.claim_header_sid%TYPE,
      p_claim_line_sid                IN       ad_claim_line.claim_line_sid%TYPE,
      p_from_service_dt               IN       ad_claim_header.from_service_date%TYPE,
      p_to_service_dt                 IN       ad_claim_header.to_service_date%TYPE,
      p_pa_request_from_dt            IN       ad_claim_header.from_service_date%TYPE,
      p_pa_request_to_dt              IN       ad_claim_header.to_service_date%TYPE,
      p_old_claim_header_sid          IN       claim_header.claim_header_sid%TYPE,
      p_clm_submission_reason_lkpcd   OUT      ad_claim_header.claim_submission_reason_lkpcd%TYPE,
      p_copay_amount                  OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_payment_amount                OUT      clm_ln_payment_info.payment_amount%TYPE,
      p_paid_service_units            OUT      clm_ln_payment_info.paid_service_units%TYPE,
      p_rac_code                      OUT      ad_clm_ln_derived_element.rac_code%TYPE,
      p_clm_type_cid                  OUT      ad_claim_line.clm_type_cid%TYPE,
      p_trtmnt_type_code              OUT      ad_clm_ln_derived_element.blng_prvdr_trtmnt_type_code%TYPE,
      p_clsfctn_group_cid             OUT      ad_claim_line.clsfctn_group_cid%TYPE,
      p_procedure_iid                 OUT      ad_claim_line.procedure_iid%TYPE,
      p_follow_up_days                OUT      procedure_detail.follow_up_days%TYPE,
      p_prcdr_code                    OUT      VARCHAR2,
      p_revenue_iid                   OUT      ad_claim_line.revenue_iid%TYPE,
      p_revenue_code                  OUT      VARCHAR2,
      p_bi_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_bi_prvdr_type_code            OUT      VARCHAR2,
      p_spclty_code                   OUT      specialty_subspecialty.spclty_code%TYPE,
      p_subspclty_code                OUT      specialty_subspecialty.subspclty_code%TYPE,
      p_proc_pccm_indctor             OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_se_prvdr_lctn_idntfr          OUT      prvdr_lctn_identifier.idntfr%TYPE,
      p_mdcr_parta_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_parta_deductible_amt%TYPE,
      p_mdcr_partb_deductible_amt     OUT      ad_clm_ln_derived_element.medicare_partb_deductible_amt%TYPE,
      p_primary_diag_code             OUT      VARCHAR2,
      p_tooth_cid                     OUT      ad_clm_ln_dental_detail.tooth_cid%TYPE,
      p_mdfr_code1                    OUT      ad_claim_line.mdfr_code1%TYPE,
      p_mdfr_code2                    OUT      ad_claim_line.mdfr_code2%TYPE,
      p_mdfr_code3                    OUT      ad_claim_line.mdfr_code3%TYPE,
      p_mdfr_code4                    OUT      ad_claim_line.mdfr_code4%TYPE,
      p_surface_cid1                  OUT      ad_clm_ln_dental_detail.surface1_cid%TYPE,
      p_surface_cid2                  OUT      ad_clm_ln_dental_detail.surface2_cid%TYPE,
      p_surface_cid3                  OUT      ad_clm_ln_dental_detail.surface3_cid%TYPE,
      p_surface_cid4                  OUT      ad_clm_ln_dental_detail.surface4_cid%TYPE,
      p_surface_cid5                  OUT      ad_clm_ln_dental_detail.surface5_cid%TYPE,
      p_quadrant_cid1                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn1_cid%TYPE,
      p_quadrant_cid2                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn2_cid%TYPE,
      p_quadrant_cid3                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn3_cid%TYPE,
      p_quadrant_cid4                 OUT      clm_ln_oral_cvty_dsgntn_detail.oral_cavity_dsgntn4_cid%TYPE,
      p_pa_utilised_amount1           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units1            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid1                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_pa_utilised_amount2           OUT      pa_rqst_prcdr_utilization.prcdr_amount%TYPE,
      p_pa_utilised_units2            OUT      pa_rqst_prcdr_utilization.prcdr_units%TYPE,
      p_pa_rqst_sid2                  OUT      ad_clm_ln_x_pa_rqst.pa_rqst_sid%TYPE,
      p_lo_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_ld_ref_idntfcn                OUT      ad_clm_ln_reference_info.reference_identification%TYPE,
      p_billed_amount                 OUT      ad_clm_ln_amount.clm_amount_value%TYPE,
      p_pa_rqst_prcdr_sid1            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_pa_rqst_prcdr_sid2            OUT      pa_request_procedure.pa_rqst_prcdr_sid%TYPE,
      p_txnmy_code                    OUT      ad_clm_ln_derived_element.txnmy_code%TYPE,
      p_quadrant_cid5                 OUT      ad_clm_ln_oral_cvty_dsgntn_dtl.oral_cavity_dsgntn5_cid%TYPE,
      p_patient_status_lkpcd          OUT      ad_clm_hdr_admission_detail.patient_status_lkpcd%TYPE,
      p_spl_clm_indctr                OUT      ad_clm_hdr_x_indicator.indctr_option_code%TYPE,
      p_allowed_amount                OUT      NUMBER,
      p_oth_pyr_paid_amount           OUT      NUMBER,
      p_high_risk_ob_care_enh_amt     OUT      NUMBER,
      p_mnl_price_flag                OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_medicare_flag                 OUT      ad_clm_ln_x_indicator.indctr_option_code%TYPE,
      p_hdr_srvcng_lctn_identifier    OUT      prvdr_lctn_identifier.idntfr%TYPE,-- Changes for MIPRO00053339
      p_drg_code                      OUT      ad_claim_header.drg_code%TYPE,--changes for MIPRO00050883
      p_sbmtd_mdfr_code1              OUT      ad_claim_line.mdfr_code1%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code2              OUT      ad_claim_line.mdfr_code2%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code3              OUT      ad_claim_line.mdfr_code3%TYPE, --Changes for MIPRO00061214
      p_sbmtd_mdfr_code4              OUT      ad_claim_line.mdfr_code4%TYPE, --Changes for MIPRO00061214
      p_err_code                      OUT      VARCHAR2,
      p_err_msg                       OUT      VARCHAR2
   )
   IS
      v_prvdr_lctn_iid              ad_clm_hdr_x_prvdr_lctn.prvdr_lctn_iid%TYPE;
      v_blng_spclty_subspclty_sid   ad_clm_ln_derived_element.blng_spclty_subspclty_sid%TYPE;
      v_pa_utilised_amount          pa_rqst_prcdr_utilization.prcdr_amount%TYPE                := 0;
      v_srvcng_prvdr_lctn_iid       ad_claim_header.srvcng_prvdr_lctn_iid%TYPE;
      v_pa_utilised_units           pa_rqst_prcdr_utilization.prcdr_units%TYPE                 := 0;
      v_cnt                         NUMBER                                                     := 0;
      v_from_service_date           VARCHAR2 (10);
      v_to_service_date             VARCHAR2 (10);
      v_errlog_code                 VARCHAR2 (10);
      v_errlog_msg                  VARCHAR2 (500);
      v_parameter_list              VARCHAR2 (2000);
      v_lo_ref_idntfcn_1            ad_clm_hdr_reference_info.reference_identification%TYPE;
      v_ld_ref_idntfcn_1            ad_clm_hdr_reference_info.reference_identification%TYPE;
      v_pa_rqst_prcdr_sid           pa_request_procedure.pa_rqst_prcdr_sid%TYPE;
      v_min_claim_line_sid          ad_claim_line.claim_line_sid%TYPE;

      CURSOR c_parqst (
         p_claim_header_sid   IN   ad_claim_line.claim_header_sid%TYPE,
         p_claim_line_sid     IN   ad_claim_line.claim_line_sid%TYPE
      )
      IS
         SELECT *
           FROM clm_ln_x_pa_rqst
          WHERE claim_line_sid = p_claim_line_sid;
   BEGIN
      v_parameter_list := '&' || 'p_claim_header_sid=' || TO_CHAR (NVL (p_claim_header_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_claim_line_sid=' || TO_CHAR (NVL (p_claim_line_sid, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_from_service_dt=' || TO_CHAR (NVL (p_from_service_dt, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_to_service_dt=' || TO_CHAR (NVL (p_to_service_dt, ''));
      v_parameter_list :=
                         v_parameter_list || '&' || 'p_pa_request_from_dt=' || TO_CHAR (NVL (p_pa_request_from_dt, ''));
      v_parameter_list := v_parameter_list || '&' || 'p_pa_request_to_dt=' || TO_CHAR (NVL (p_pa_request_to_dt, ''));
      v_parameter_list :=
                     v_parameter_list || '&' || 'p_old_claim_header_sid=' || TO_CHAR (NVL (p_old_claim_header_sid, ''));

      BEGIN
         SELECT patient_status_lkpcd
           INTO p_patient_status_lkpcd
           FROM clm_hdr_admission_detail
          WHERE claim_header_sid = p_claim_header_sid;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_patient_status_lkpcd := NULL;
      END;
     BEGIN
         SELECT indctr_option_code
           INTO p_spl_clm_indctr
           FROM clm_ln_x_indicator
          WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid =(SELECT indctr_type_cid      
                       FROM indicator_type
                        WHERE indctr_type_desc = 'SPECIAL CLAIM INDICATOR');
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            BEGIN
               SELECT indctr_option_code
                 INTO p_spl_clm_indctr
                 FROM clm_hdr_x_indicator
                WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid =(SELECT indctr_type_cid      
                       FROM indicator_type
                        WHERE indctr_type_desc = 'SPECIAL CLAIM INDICATOR');
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  p_spl_clm_indctr := NULL;
            END;
      END;

      /*Get payment details for line*/
      BEGIN

         SELECT cld.rac_code, cld.clm_type_cid, cld.blng_prvdr_trtmnt_type_code,   --Rev1.15
                                                                                cld.clsfctn_group_cid,
                TO_CHAR (cl.from_service_date, 'MM/DD/YYYY'), TO_CHAR (cl.to_service_date, 'MM/DD/YYYY'),
                NVL (cl.srvcng_prvdr_lctn_iid, 0), NVL (cld.blng_spclty_subspclty_sid, 0), NVL (cld.paid_amount, 0),
                NVL (cld.paid_srvc_units, 0), cld.txnmy_code, fn_iidtorefcode (cl.primary_diagnosis_iid),
                cld.copay_amount, cl.mdfr_code1, cl.mdfr_code2, cl.mdfr_code3, cl.mdfr_code4, cl.billed_amount,
                cl.procedure_iid, cl.prcdr_code, cl.revenue_iid, cl.revenue_code, 
                NVL(cld.drvd_srvcng_prvdr_lctn_iid, cl.srvcng_prvdr_lctn_iid),--modified as per CQ#52349
                cld.medicare_parta_deductible_amt, cld.medicare_partb_deductible_amt,
                cl.sbmtd_mdfr_code_1,cl.sbmtd_mdfr_code_2,cl.sbmtd_mdfr_code_3,cl.sbmtd_mdfr_code_4   --changes for MIPRO00061214
           INTO p_rac_code, p_clm_type_cid, p_trtmnt_type_code, p_clsfctn_group_cid,
                v_from_service_date, v_to_service_date,
                v_prvdr_lctn_iid, v_blng_spclty_subspclty_sid, p_payment_amount,
                p_paid_service_units, p_txnmy_code, p_primary_diag_code,
                p_copay_amount, p_mdfr_code1, p_mdfr_code2, p_mdfr_code3, p_mdfr_code4, p_billed_amount,
                p_procedure_iid, p_prcdr_code, p_revenue_iid, p_revenue_code, p_se_prvdr_lctn_idntfr,
                p_mdcr_parta_deductible_amt, p_mdcr_partb_deductible_amt,
                p_sbmtd_mdfr_code1,p_sbmtd_mdfr_code2,p_sbmtd_mdfr_code3,p_sbmtd_mdfr_code4   --changes for MIPRO00061214
           FROM clm_ln_derived_element cld, claim_line cl
          WHERE cl.claim_line_sid = p_claim_line_sid AND cl.claim_line_sid = cld.claim_line_sid(+);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_rac_code := NULL;
            p_clm_type_cid := NULL;
            p_trtmnt_type_code := NULL;
            p_clsfctn_group_cid := NULL;
            p_payment_amount := NULL;
            p_paid_service_units := NULL;
            p_txnmy_code := NULL;
            p_primary_diag_code := NULL;
            p_copay_amount := NULL;
            p_mdfr_code1 := NULL;
            p_mdfr_code2 := NULL;
            p_mdfr_code3 := NULL;
            p_mdfr_code4 := NULL;
            p_billed_amount := NULL;
            p_procedure_iid := NULL;
            p_revenue_iid := NULL;
            p_prcdr_code := NULL;
            p_revenue_code := NULL;
            p_se_prvdr_lctn_idntfr := NULL;
            p_mdcr_parta_deductible_amt := NULL;
            p_mdcr_partb_deductible_amt := NULL;
            p_sbmtd_mdfr_code1 := NULL;
            p_sbmtd_mdfr_code2 := NULL;
            p_sbmtd_mdfr_code3 := NULL;
            p_sbmtd_mdfr_code4 := NULL;
      END;

      BEGIN
         SELECT indctr_option_code
           INTO p_medicare_flag
           FROM clm_hdr_x_indicator
          WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = 737 AND ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_medicare_flag := NULL;
      END;

      IF NVL (p_clm_type_cid, -99) = 2 THEN
         BEGIN
            SELECT indctr_option_code
              INTO p_mnl_price_flag
              FROM clm_hdr_x_indicator
             WHERE claim_header_sid = p_claim_header_sid AND indctr_type_cid = 140 AND ROWNUM = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mnl_price_flag := NULL;
         END;
      ELSE
         BEGIN
            SELECT indctr_option_code
              INTO p_mnl_price_flag
              FROM clm_ln_x_indicator
             WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = 140 AND ROWNUM = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mnl_price_flag := NULL;
         END;
      END IF;     


      /*Get procedure iid*/
      BEGIN
         SELECT pd.follow_up_days
           INTO p_follow_up_days
           FROM procedure_detail pd, procedure_status ps
          WHERE pd.procedure_iid = NVL (p_procedure_iid, p_revenue_iid)
            AND pd.procedure_iid = ps.procedure_iid
            AND pd.prcdr_dtl_sid = ps.prcdr_dtl_sid
            AND ps.status_type_cid = 1
            AND ps.status_cid = 2
            AND ps.oprtnl_flag = 'A'
            AND fn_getanchordt (p_from_service_dt, p_to_service_dt) BETWEEN ps.from_date AND ps.TO_DATE;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_follow_up_days := NULL;
      END;
     BEGIN
         SELECT blng_prvdr_lctn_iid, blng_prvdr_type_code, claim_submission_reason_lkpcd, 
                NVL(chde.drvd_srvcng_prvdr_lctn_iid,ch.srvcng_prvdr_lctn_iid),--Changed as per MIPRO00052349
                (SELECT MIN (claim_line_sid)
                   FROM claim_line
                  WHERE claim_header_sid = ch.claim_header_sid) min_claim_line_sid
           INTO p_bi_prvdr_lctn_idntfr, p_bi_prvdr_type_code, p_clm_submission_reason_lkpcd, v_srvcng_prvdr_lctn_iid,
                v_min_claim_line_sid
           FROM claim_header ch,
                clm_hdr_derived_element chde --Added as per CQ#52349
          WHERE ch.claim_header_sid = p_claim_header_sid
            AND chde.claim_header_sid=ch.claim_header_sid ;--Added as per CQ#52349

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_bi_prvdr_type_code := NULL;
            p_bi_prvdr_lctn_idntfr := NULL;
            p_clm_submission_reason_lkpcd := NULL;
            v_srvcng_prvdr_lctn_iid := NULL;
      END;

      p_se_prvdr_lctn_idntfr := NVL (p_se_prvdr_lctn_idntfr, v_srvcng_prvdr_lctn_iid);

      p_hdr_srvcng_lctn_identifier := v_srvcng_prvdr_lctn_iid; -- Changes for MIPRO00053339
      IF v_blng_spclty_subspclty_sid <> 0 THEN
         --Get spclty, subspclty code
         SELECT ssp.spclty_code, ssp.subspclty_code
           INTO p_spclty_code, p_subspclty_code
           FROM specialty_subspecialty ssp
          WHERE ssp.spclty_subspclty_sid = v_blng_spclty_subspclty_sid AND ssp.oprtnl_flag = 'A';
      END IF;

      /*Get indicator option*/
      BEGIN
         SELECT indctr_option_code
           INTO p_proc_pccm_indctor
           FROM clm_ln_x_indicator
          WHERE claim_line_sid = p_claim_line_sid AND indctr_type_cid = 137 AND indctr_option_code = 'Y';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_proc_pccm_indctor := NULL;
      END;

       v_cnt := 1;
      /*Derive tooth,surface cid*/
      BEGIN
         SELECT surface1_cid, surface2_cid, surface3_cid, surface4_cid, tooth_cid
           INTO p_surface_cid1, p_surface_cid2, p_surface_cid3, p_surface_cid4, p_tooth_cid
           FROM clm_ln_dental_detail
          WHERE clm_ln_dental_detail_sid=
                (SELECT   MIN (clm_ln_dental_detail_sid)
                       FROM   clm_ln_dental_detail k
                      WHERE   k.claim_line_sid = p_claim_line_sid);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_surface_cid1 := NULL;
            p_surface_cid2 := NULL;
            p_surface_cid3 := NULL;
            p_surface_cid4 := NULL;
            p_tooth_cid := NULL;
      END;

      /*Initailize count*/
      v_cnt := 1;

      BEGIN
         SELECT oral_cavity_dsgntn1_cid, oral_cavity_dsgntn2_cid, oral_cavity_dsgntn3_cid, oral_cavity_dsgntn4_cid,
                oral_cavity_dsgntn5_cid
           INTO p_quadrant_cid1, p_quadrant_cid2, p_quadrant_cid3, p_quadrant_cid4,
                p_quadrant_cid5
           FROM clm_ln_oral_cvty_dsgntn_detail   -- should be ad table
          WHERE claim_line_sid = p_claim_line_sid;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_quadrant_cid1 := NULL;
            p_quadrant_cid2 := NULL;
            p_quadrant_cid3 := NULL;
            p_quadrant_cid4 := NULL;
            p_quadrant_cid5 := NULL;
      END;

      /*Initialize count*/
      v_cnt := 0;

      /*Process cursor for pa requests*/
      FOR parqst_rec IN c_parqst (p_claim_header_sid, p_claim_line_sid) LOOP
         /*Increment the count*/
         v_cnt := (v_cnt + 1);

         /*Get utilised units, amount*/
         BEGIN
            SELECT   SUM (NVL (pu.prcdr_amount, 0)), SUM (NVL (pu.prcdr_units, 0)), pp.pa_rqst_prcdr_sid
                INTO v_pa_utilised_amount, v_pa_utilised_units, v_pa_rqst_prcdr_sid
                FROM pa_request_service prs, pa_request_procedure pp, pa_rqst_prcdr_utilization pu
               WHERE prs.pa_rqst_sid = parqst_rec.pa_rqst_sid
                 AND prs.oprtnl_flag = 'A'
                 AND prs.pa_rqst_srvc_sid = pp.pa_rqst_srvc_sid
                 AND pp.procedure_iid = p_procedure_iid
                 AND pp.oprtnl_flag = 'A'
                 AND pp.status_cid = 20
                 AND pp.pa_rqst_prcdr_sid = pu.pa_rqst_prcdr_sid
                 AND pu.oprtnl_flag = 'A'
                 AND pu.from_date <= p_pa_request_from_dt
                 AND pu.TO_DATE >= p_pa_request_to_dt
            GROUP BY pp.pa_rqst_prcdr_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_pa_utilised_amount := NULL;
               v_pa_utilised_units := NULL;
               v_pa_rqst_prcdr_sid := NULL;
         END;

         /*Check whether this has to be assigned to 1 or 2*/
         IF v_cnt = 1 THEN
            p_pa_utilised_amount1 := v_pa_utilised_amount;
            p_pa_utilised_units1 := v_pa_utilised_units;
            p_pa_rqst_sid1 := parqst_rec.pa_rqst_sid;
            p_pa_rqst_prcdr_sid1 := v_pa_rqst_prcdr_sid;
         ELSIF v_cnt = 2 THEN
            p_pa_utilised_amount2 := v_pa_utilised_amount;
            p_pa_utilised_units2 := v_pa_utilised_units;
            p_pa_rqst_sid2 := parqst_rec.pa_rqst_sid;
            p_pa_rqst_prcdr_sid2 := v_pa_rqst_prcdr_sid;
         END IF;
      END LOOP;

      /*Get origin code*/
      BEGIN
         -- Merged both into ONE statement using DECODE version 1.7
         SELECT DECODE (reference_info_lkpcd, 'LO', reference_identification, NULL),
                DECODE (reference_info_lkpcd, 'LD', reference_identification, NULL)
           INTO v_lo_ref_idntfcn_1,
                v_ld_ref_idntfcn_1
           FROM clm_ln_reference_info
          WHERE claim_line_sid = p_claim_line_sid;

         p_lo_ref_idntfcn := v_lo_ref_idntfcn_1;
         p_ld_ref_idntfcn := v_ld_ref_idntfcn_1;

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_lo_ref_idntfcn := NULL;
            p_ld_ref_idntfcn := NULL;
         WHEN TOO_MANY_ROWS THEN
            BEGIN
               SELECT reference_identification
                 INTO v_lo_ref_idntfcn_1
                 FROM clm_ln_reference_info
                WHERE claim_line_sid = p_claim_line_sid AND reference_info_lkpcd = 'LO';
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_lo_ref_idntfcn_1 := NULL;
            END;

            BEGIN
               SELECT reference_identification
                 INTO v_ld_ref_idntfcn_1
                 FROM clm_ln_reference_info
                WHERE claim_line_sid = p_claim_line_sid AND reference_info_lkpcd = 'LD';
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_ld_ref_idntfcn_1 := NULL;
            END;
      END;

      IF p_clm_type_cid = 2 AND p_claim_line_sid = v_min_claim_line_sid THEN
         BEGIN
            SELECT medicare_parta_deductible_amt, medicare_partb_deductible_amt
              INTO p_mdcr_parta_deductible_amt, p_mdcr_partb_deductible_amt
              FROM clm_hdr_derived_element
             WHERE claim_header_sid = p_claim_header_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_mdcr_parta_deductible_amt := NULL;
               p_mdcr_partb_deductible_amt := NULL;
         END;
      END IF;

   /* Get DRG CODE */   
      IF p_clm_type_cid = 2  THEN
         BEGIN
            SELECT NVL(achde.drg_code,ach.drg_code)
              INTO p_drg_code
              FROM clm_hdr_derived_element achde ,claim_header ach
             WHERE ach.claim_header_sid = p_claim_header_sid
               AND ach.claim_header_sid=achde.claim_header_sid;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               p_drg_code := NULL;
         END;
      END IF;
   /* Get DRG CODE */   

      /*Successful*/
      p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_SUCCESS;      --vers Cloud RE 1.0.1
      p_err_msg := 'Successful...';
   EXCEPTION
      WHEN OTHERS THEN
         p_err_code := PK_ERR_CNSTN.C_ERR_CNSTN_COMMON;    --vers Cloud RE 1.0.1
         p_err_msg := SUBSTR (SQLERRM, 1, 200) || DBMS_UTILITY.format_error_backtrace;
         v_parameter_list := 'p_err_code=' || TO_CHAR (p_err_code)
                            ||'-'||SQLCODE|| NVL (v_parameter_list, ''); --vers Cloud RE 1.0.1
         pr_clmprcsngerrlog (p_old_claim_header_sid,
                             NULL,
                             NULL,
                             NULL,
                             'pk_MbrHistory',
                             'pr_getclmdataelement_wip',
                             v_parameter_list,
                             p_err_msg,
                             NULL,
                             '1',
                             SYSDATE,
                             v_errlog_code,
                             v_errlog_msg
                            );
   END pr_getclmdataelement_wip;
--Changes End for CQ#70112
END pk_mbrhistory;
/
