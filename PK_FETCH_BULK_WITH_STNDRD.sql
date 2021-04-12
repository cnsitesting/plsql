create or replace PACKAGE pk_fetch_bulk_with_stndrd
AS
/******************************************************************************
   NAME:       PK_FETCH_BULK_WITH_STNDRD
   PURPOSE:   To validate Sonarqube Rule: AvoidFetchBulkCollectIntoWithoutLimitCheck

   REVISIONS:
   Ver       Date          Author         Description
   -------  ------------  -------------  ------------------------------------
   1.0       04/05/2021      Sridevi        Created this procedure.
******************************************************************************/
   PROCEDURE pr_move_edifecs (p_interface_sid          IN     NUMBER,
                              p_interface_run_sid      IN     NUMBER,
                              p_total_records             OUT NUMBER,
                              p_total_error_recs          OUT NUMBER,
                              p_total_succesful_recs      OUT NUMBER);
   c_oprtnl_flag                CONSTANT CHAR (1) := 'A';
   c_limit                  NUMBER := 1000; -- Added limit
    CURSOR g_cur_get_pa_line_info(cp_pa_rqst_sid IN pa_request.pa_rqst_sid%TYPE) 
  IS
     SELECT PAPROC.PA_RQST_PRCDR_SID,
        PAPROC.DM_CODE_LIST_QLFR_LKPCD ,
        DECODE (PAPROC.DM_CODE_LIST_QLFR_LKPCD, 'P', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'S', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'SA', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'B',
        (SELECT GROUP_CODE FROM GROUPS WHERE GROUP_CID = PAPROC.BLANKET_GROUP_CID
        ), 'N', PAPROC.DRUG_CODE, 'R', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'X', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'Y', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID), 'Z', FN_IIDTOREFCODE (PAPROC.PROCEDURE_IID) ) prcdr_Code,
        PRXPL.PRVDR_LCTN_IID ,
        (SELECT TO_CHAR (FROM_DATE, 'MM/DD/YYYY')
        FROM PA_RQST_PRCDR_TRANSACTION
        WHERE PA_RQST_PRCDR_TXN_SID =
          (SELECT MAX (PA_RQST_PRCDR_TXN_SID)
          FROM PA_RQST_PRCDR_TRANSACTION PTXN2
          WHERE PTXN2.OPRTNL_FLAG = 'A'
          AND PA_RQST_PRCDR_SID   = PAPROC.PA_RQST_PRCDR_SID
          )
        ) prcdr_from_date,
        (SELECT TO_CHAR (TO_DATE, 'MM/DD/YYYY')
        FROM PA_RQST_PRCDR_TRANSACTION
        WHERE PA_RQST_PRCDR_TXN_SID =
          (SELECT MAX (PA_RQST_PRCDR_TXN_SID)
          FROM PA_RQST_PRCDR_TRANSACTION PTXN2
          WHERE PTXN2.OPRTNL_FLAG = 'A'
          AND PA_RQST_PRCDR_SID   = PAPROC.PA_RQST_PRCDR_SID
          )
        ) prcdr_to_date,
        PAPROC.MDFR_CODE  mdfr_code1,
         PAPROC.MDFR2_CODE  mdfr_code2,
        PAPROC.MDFR3_CODE  mdfr_code3,
         PAPROC.MDFR4_CODE  mdfr_code4,
        PAPROC.TOOTH_NUMBER_CID AS TOOTH_NUMBER_CID,
        paproc.line_nmbr,
        paproc.procedure_iid,
        paproc.status_Cid as prcdr_status_cid,
		parqsvc.x12_pa_srvc_type_code          --Ver 1.8
   FROM pa_request_procedure paproc,
        pa_request_service parqsvc,
        pa_request parq,
        pa_request_x_provider_location prxpl,
        pa_rqst_prcdr_x_prvdr_lctn prrxpl
  WHERE paproc.pa_rqst_srvc_sid       = parqsvc.pa_rqst_srvc_sid
  AND parq.pa_rqst_sid                = parqsvc.pa_rqst_sid
  AND parq.pa_rqst_sid                = prxpl.pa_rqst_sid
  AND prrxpl.pa_rqst_prcdr_sid        = paproc.pa_rqst_prcdr_sid
  AND prrxpl.pa_rqst_x_prvdr_lctn_sid = prxpl.pa_rqst_x_prvdr_lctn_sid
  AND prxpl.oprtnl_flag               = c_oprtnl_flag
  AND paproc.oprtnl_flag              = c_oprtnl_flag
  AND parqsvc.oprtnl_flag             = c_oprtnl_flag
  AND parq.oprtnl_flag                = c_oprtnl_flag
  AND prrxpl.oprtnl_flag              = c_oprtnl_flag
  AND parq.pa_rqst_sid                = cp_pa_rqst_sid
  AND PRXPL.PA_PRVDR_TYPE_LKPCD       = 'SP'
  ORDER BY PAPROC.PA_RQST_PRCDR_SID ASC;
  
  TYPE nt_pa_ln_info IS TABLE  OF g_cur_get_pa_line_info%ROWTYPE;
   gt_pa_ln_info  nt_pa_ln_info  := nt_pa_ln_info();
END pk_fetch_bulk_with_stndrd;
/
create or replace PACKAGE BODY pk_fetch_bulk_with_stndrd
AS
/******************************************************************************
   NAME:       PK_FETCH_BULK_WITH_STNDRD
   PURPOSE:   To validate Sonarqube Rule: AvoidFetchBulkCollectIntoWithoutLimitCheck

   REVISIONS:
   Ver       Date          Author         Description
   -------  ------------  -------------  ------------------------------------
   1.0       04/05/2021      Sridevi        Created this procedure.
******************************************************************************/
--> Fetch bulk collect approach 1 (limit with looping)
   PROCEDURE pr_move_edifecs (p_interface_sid          IN     NUMBER,
                              p_interface_run_sid      IN     NUMBER,
                              p_total_records             OUT NUMBER,
                              p_total_error_recs          OUT NUMBER,
                              p_total_succesful_recs      OUT NUMBER)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      CURSOR c1
      IS
         SELECT *
           FROM ist_edifecs_data
          WHERE ff_stg_sid = p_interface_run_sid;

      TYPE c1_type IS TABLE OF c1%ROWTYPE;

      c1_rec                   c1_type;
      v_ctgry                  VARCHAR2 (25);
      v_edifecs_category_sid   NUMBER;
      v_user_note              EDIFECS_STG_DATA.COL5%TYPE;
      v_oracle_error           CHAR (1) := 'N';
   BEGIN
      p_total_records := 0;
      p_total_error_recs := 0;
      p_total_succesful_recs := 0;

      v_ctgry := '132_C';

      SELECT MAX (edifecs_tgt_category_sid)
        INTO v_edifecs_category_sid
        FROM EDIFECS_TGT_CATEGORY
       WHERE UPPER (ctgry) = v_ctgry AND oprtnl_flag = 'A';

      OPEN c1;
      LOOP
      FETCH c1
      BULK COLLECT INTO c1_rec LIMIT c_limit; -- Added limit with loop

      FOR i IN c1_rec.FIRST .. c1_rec.LAST
      LOOP
         BEGIN
            p_total_records := p_total_records + 1;

            INSERT INTO EDIFECS_STG_DATA (edifecs_stg_data_sid,
                                          edifecs_tgt_category_sid,
                                          ctgry,
                                          col1,
                                          col2,
                                          col3,
                                          col4,
                                          col5,
                                          col6,
                                          col7,
                                          col8,
                                          col9,
                                          col10,
                                          actn_cd,
                                          feed_date,
                                          filename,
                                          created_date,
                                          created_by,
                                          modified_date,
                                          modified_by,
                                          from_date,
                                          TO_DATE)
                 VALUES (
                           edifecs_stg_data_seq.NEXTVAL,
                           v_edifecs_category_sid,
                           v_ctgry,
                           TRIM (c1_rec (i).KEY),
                           TRIM (c1_rec (i).VALUE),
                           TRIM (c1_rec (i).excluded),
                           TRIM (c1_rec (i).NAME),
                           v_user_note,
                           NULL,
                           NULL,
                           NULL,
                           NULL,
                           NULL,
                           NULL,
                           c1_rec (i).start_date,
                           c1_rec (i).file_name,
                           SYSDATE,
                           1,
                           SYSDATE,
                           1,
                           c1_rec (i).start_date,
                           NVL (c1_rec (i).end_date,
                                TO_DATE ('12/31/2999', 'MM/DD/YYYY'))
                                                                     );

         EXCEPTION
            WHEN OTHERS
            THEN
               p_total_error_recs := p_total_error_recs + 1;
                 pk_db_error.pr_log (
                    p_object_name        => 'pr_move_edifecs',
                    p_sub_routine_name   => 'pr_move_edifecs',
                    p_error_code         => SQLCODE,
                    p_error_msg          => SQLERRM,
                    p_error_details      =>    'Error Call to pr_move_edifecs: '
                                            || SUBSTR (SQLERRM, 1, 200)
                                            || DBMS_UTILITY.format_error_backtrace ());
               EXIT;
         END;
      END LOOP;
        EXIT WHEN c1%NOTFOUND;
      END LOOP;

      CLOSE c1;
      p_total_succesful_recs := p_total_records - p_total_error_recs;
   EXCEPTION
      WHEN OTHERS
      THEN
         pk_db_error.pr_log (
            p_object_name        => 'pr_move_edifecs',
            p_sub_routine_name   => 'pr_move_edifecs',
            p_error_code         => SQLCODE,
            p_error_msg          => SQLERRM,
            p_error_details      =>    'Error Call to pr_move_edifecs: '
                                    || SUBSTR (SQLERRM, 1, 200)
                                    || DBMS_UTILITY.format_error_backtrace ());
   END pr_move_edifecs;
   --> Fetch bulk collect approach 2 (limit without looping)
    PROCEDURE pr_load_pa_data(p_pa_rqst_sid IN pa_request.pa_rqst_sid%TYPE,
                         p_err_code OUT VARCHAR2,
                         p_err_msg OUT VARCHAR2 )
      AS
      BEGIN
        OPEN  g_cur_get_pa_line_info(p_pa_rqst_sid );
        FETCH g_cur_get_pa_line_info BULK COLLECT INTO gt_pa_ln_info LIMIT c_limit; -- Added limit without loop
        CLOSE g_cur_get_pa_line_info;  
      EXCEPTION
      WHEN OTHERS THEN
        p_err_code := SQLCODE;
        pk_db_error.pr_log (p_object_name =>'PR_LOAD_PA_DATA', p_sub_routine_name =>'PR_LOAD_PA_DATA', p_error_code => SQLCODE, -- Log Actual Oracle Error Code.
        p_error_msg => SQLERRM,                                                                                                     -- Log Actual Oracle Error Msg/User Defined error message
        p_error_details =>'p_pa_rqst_sid - '||p_pa_rqst_sid||'.'||dbms_utility.format_Error_backtrace());
    END pr_load_pa_data ;
END pk_fetch_bulk_with_stndrd;
/