create or replace PACKAGE pk_rules_test_with_stndrd
AS
/******************************************************************************
   NAME:       PK_RULES_TEST_WITH_STNDRD
   PURPOSE:   To validate Sonarqube Rule: BadRaiseApplicationErrorUsageCheck, FunctionLastStatementReturnCheck, VariableRedeclaration, ForallStatementShouldUseSaveExceptionsClause

   REVISIONS:
   Ver       Date          Author         Description
   -------  ------------  -------------  ------------------------------------
   1.0       04/07/2021      Sridevi        Created this procedure.
******************************************************************************/
    FUNCTION fn_gen_file_id (
        p_previous_code IN VARCHAR2
    ) RETURN VARCHAR2;
    FUNCTION fn_validate_cci_mod_ind (p_mdfr_csv            IN VARCHAR2,
                                      p_service_from_date   IN VARCHAR2,
                                      p_service_to_date     IN VARCHAR2)
      RETURN VARCHAR2;
    FUNCTION fn_getpacrtfctnnmbr
      RETURN VARCHAR2;
    PROCEDURE pr_clm_pa_rec (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    );
    PROCEDURE pr_clm_pa_rec_1 (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    );
    PROCEDURE pr_clm_pa_rec_2 (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    );
END pk_rules_test_with_stndrd;
/
create or replace PACKAGE BODY pk_rules_test_with_stndrd
AS
/******************************************************************************
   NAME:       PK_RULES_TEST_WITH_STNDRD
   PURPOSE:   To validate Sonarqube Rule: BadRaiseApplicationErrorUsageCheck, FunctionLastStatementReturnCheck, VariableRedeclaration, ForallStatementShouldUseSaveExceptionsClause

   REVISIONS:
   Ver       Date          Author         Description
   -------  ------------  -------------  ------------------------------------
   1.0       04/07/2021      Sridevi        Created this procedure.
******************************************************************************/
--> Function Return Scenario 1
    FUNCTION fn_gen_file_id (
        p_previous_code IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_voucher_num   VARCHAR2(32767);
        v_exhaust       VARCHAR2(32767);
        v_alpha         VARCHAR2(32767);
        v_number        NUMBER(38);
        out_of_bound EXCEPTION;
        /* Removed redeclared variables which were not used in the function */
--        v_cnt           NUMBER;
--        v_cnt           NUMBER;
    BEGIN
        IF p_previous_code IS NULL THEN
            SELECT
                'A00001'
            INTO v_voucher_num
            FROM
                dual;
        ELSIF ( to_number(ascii(substr(p_previous_code, 1, 1)), 99) BETWEEN 65 AND 90 ) THEN
            v_alpha := substr(p_previous_code, 1, 1);
            v_number := to_number(substr(p_previous_code, 2, 6), 99999);
            BEGIN
                IF substr(p_previous_code, 1, 6) = 'Z99999' THEN
                    RAISE out_of_bound;
                    v_voucher_num := v_exhaust;
                ELSIF substr(p_previous_code, 2, 6) = '99999' THEN
                    SELECT
                        chr((ascii(v_alpha) + 1) + trunc(1 / 100))
                        || to_char(mod(v_number, 99999) + 1, 'FM00000')
                    INTO v_exhaust
                    FROM
                        dual;
                ELSE
                    SELECT
                        chr((ascii(v_alpha)) + trunc(1 / 100))
                        || to_char(mod(v_number, 99999) + 1, 'FM00000')
                    INTO v_exhaust
                    FROM
                        dual;
                END IF;
                v_voucher_num := v_exhaust;
            END;
        END IF;
        RETURN v_voucher_num; -- Made use of existing variable and returned at the end of statement
    EXCEPTION
        WHEN out_of_bound THEN
            raise_application_error(-20000, 'Voucher number out of bound.'); -- associate error code from 20000 to 20999 to the error msg
    END fn_gen_file_id;
--> Function Return Scenario 2
   FUNCTION fn_validate_cci_mod_ind (p_mdfr_csv            IN VARCHAR2,
                                     p_service_from_date   IN VARCHAR2,
                                     p_service_to_date     IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_cnt   NUMBER;
      v_cci_mod_ind_flag VARCHAR2 (1);
   BEGIN
      SELECT   COUNT ( * )
        INTO   v_cnt
        FROM   modifier_indicator
       WHERE   mdfr_code IN
                     (SELECT   COLUMN_VALUE
                        FROM   TABLE(pk_reference_utility.fn_csv2array (
                                        p_mdfr_csv
                                     )))
               AND indctr_type_cid = 174
               AND indctr_option_code = 'Y'
               AND oprtnl_flag = 'A'
               AND status_cid = 2
               AND TO_DATE (p_service_from_date, 'MM/DD/YYYY') BETWEEN from_date
                                                                   AND  TO_DATE
               AND TO_DATE (p_service_to_date, 'MM/DD/YYYY') BETWEEN from_date
                                                                 AND  TO_DATE;

      IF v_cnt > 0
      THEN
         v_cci_mod_ind_flag:= 'Y';
      ELSE
         v_cci_mod_ind_flag:= 'N';
      END IF;
      RETURN v_cci_mod_ind_flag; -- Created a variable and returned at the end of statement
   END fn_validate_cci_mod_ind;
--> Function Return Scenario 3
   FUNCTION fn_getpacrtfctnnmbr
      RETURN VARCHAR2
   AS
      PRAGMA AUTONOMOUS_TRANSACTION;
   
      CURSOR c
      IS
         SELECT *
           FROM (SELECT   ROWID rid, next_crtfctn_nmbr
                     FROM pa_crtfcn_nmbr_table
                    WHERE oprtnl_flag = 'A'
                    and RQST_TYPE_LKPCD='PA'
                 ORDER BY next_crtfctn_nmbr)
          WHERE ROWNUM = 1;
      l_next_nmbr   pa_crtfcn_nmbr_table.next_crtfctn_nmbr%TYPE   := '0';
      l_end_flag    INTEGER                                       := 1;
      v_getpacrtfctnnmbr  pa_crtfcn_nmbr_table.next_crtfctn_nmbr%TYPE;
   BEGIN
      LOOP
         FOR r IN c
         LOOP
            l_next_nmbr := r.next_crtfctn_nmbr;
   
            BEGIN
               DELETE      pa_crtfcn_nmbr_table
                     WHERE ROWID = r.rid;
   
               COMMIT;
               l_end_flag := 1;
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_end_flag := 0;
            END;
         END LOOP;
   
         IF l_end_flag = 1
         THEN
            v_getpacrtfctnnmbr := l_next_nmbr;
            EXIT; -- Created a variable to store the next number and EXIT (since the same variable will be reassigned in loop)
         END IF;
      END LOOP;
      RETURN v_getpacrtfctnnmbr;
   END fn_getpacrtfctnnmbr;
-- FORALL SAVE EXCEPTIONS Approach 1
    PROCEDURE pr_clm_pa_rec (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    )
        IS
    TYPE typ_clm_pa_rec IS
        TABLE OF ist_ili5200_clm_pa_rec%rowtype;
    t_clm_pa_rec typ_clm_pa_rec;
    BEGIN
        p_err_code := '0';
        p_err_msg := 'Success';
        SELECT
            *
        BULK COLLECT INTO
            t_clm_pa_rec
        FROM
            ist_ili5200_clm_pa_rec
        WHERE
            actual_rec_no = p_actual_rec_no
            AND   ff_stg_sid = p_interface_run_sid;

        FORALL k IN t_clm_pa_rec.first..t_clm_pa_rec.last SAVE EXCEPTIONS
            INSERT INTO ad_rx_p_clm_hdr_prior_athrztn (
                rx_clm_hdr_prior_athrztn_sid,
                rx_claim_header_sid,
                prior_athrztn_type_lkpcd,
                prior_athrztn_nmbr,
                prior_athrztn_sbmtd_nmbr,
                prior_athrztn_asgnd_nmbr,
                created_by,
                created_date,
                modified_by,
                modified_date,
                pa_step_order,
                auto_pa_code,
                pa_type
            ) VALUES (
                ad_rx_p_clm_hdr_pa_seq.NEXTVAL,
                p_rx_claim_header_sid,
                NULL,
                t_clm_pa_rec(k).prior_auth_number,
                NULL,
                NULL,
                1,
                SYSDATE,
                1,
                SYSDATE,
                NULL,
                t_clm_pa_rec(k).auto_pa_cd,
                t_clm_pa_rec(k).pa_type
            );

    EXCEPTION
        WHEN pk_common_dmlerr_logging.dml_errors THEN 
            pk_common_dmlerr_logging.pr_bulk_msg_dump;
        WHEN OTHERS THEN
            p_err_code := sqlcode;
            p_err_msg := 'Error in pr_clm_pa_rec -:'
            || substr(sqlerrm,1,200)
            || dbms_utility.format_error_backtrace ();

            pk_db_error.pr_log(p_object_name => 'pk_rules_test_with_stndrd',p_sub_routine_name => 'pr_clm_pa_rec',p_error_code => p_err_code,p_error_msg => p_err_msg,p_error_details => p_err_msg || ' - p_rx_claim_header_sid (' || p_rx_claim_header_sid || ')');
    END pr_clm_pa_rec;
-- FORALL SAVE EXCEPTIONS Approach 2
    PROCEDURE pr_clm_pa_rec_1 (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    )
        IS
    TYPE typ_clm_pa_rec IS
        TABLE OF ist_ili5200_clm_pa_rec%rowtype;
    t_clm_pa_rec typ_clm_pa_rec;
    e_dml_errors EXCEPTION;
    pragma exception_init (e_dml_errors, -24381);
    v_error_details CLOB;
    BEGIN
        p_err_code := '0';
        p_err_msg := 'Success';
        SELECT
            *
        BULK COLLECT INTO
            t_clm_pa_rec
        FROM
            ist_ili5200_clm_pa_rec
        WHERE
            actual_rec_no = p_actual_rec_no
            AND   ff_stg_sid = p_interface_run_sid;

        FORALL k IN t_clm_pa_rec.first..t_clm_pa_rec.last SAVE EXCEPTIONS
            INSERT INTO ad_rx_p_clm_hdr_prior_athrztn (
                rx_clm_hdr_prior_athrztn_sid,
                rx_claim_header_sid,
                prior_athrztn_type_lkpcd,
                prior_athrztn_nmbr,
                prior_athrztn_sbmtd_nmbr,
                prior_athrztn_asgnd_nmbr,
                created_by,
                created_date,
                modified_by,
                modified_date,
                pa_step_order,
                auto_pa_code,
                pa_type
            ) VALUES (
                ad_rx_p_clm_hdr_pa_seq.NEXTVAL,
                p_rx_claim_header_sid,
                NULL,
                t_clm_pa_rec(k).prior_auth_number,
                NULL,
                NULL,
                1,
                SYSDATE,
                1,
                SYSDATE,
                NULL,
                t_clm_pa_rec(k).auto_pa_cd,
                t_clm_pa_rec(k).pa_type
            );

    EXCEPTION
        WHEN e_dml_errors THEN
          p_err_code:=SQLCODE;
          p_err_msg := 'Error while inserting in ad_rx_p_clm_hdr_prior_athrztn' || sqlerrm;
          FOR i IN 1 .. sql%bulk_exceptions.count
          LOOP
            v_error_details := 'Error -: '|| i || ' Array Index -: '|| sql%bulk_exceptions
            (
              i
            )
            .error_index || ' Message -: '|| sqlerrm
            (
              -sql%bulk_exceptions(i).error_code
            );

            pk_db_error.pr_log( p_object_name => 'pk_rules_test_with_stndrd', p_sub_routine_name => 'pr_clm_pa_rec_1', p_error_code => p_err_code, p_error_msg => v_error_details, p_error_details => v_error_details || ' - p_rx_claim_header_sid ('|| p_rx_claim_header_sid || ')' );
          END LOOP;
        WHEN OTHERS THEN
            p_err_code := sqlcode;
            p_err_msg := 'Error in pr_clm_pa_rec_1 -:'
            || substr(sqlerrm,1,200)
            || dbms_utility.format_error_backtrace ();

            pk_db_error.pr_log(p_object_name => 'pk_rules_test_with_stndrd',p_sub_routine_name => 'pr_clm_pa_rec_1',p_error_code => p_err_code,p_error_msg => p_err_msg,p_error_details => p_err_msg || ' - p_rx_claim_header_sid (' || p_rx_claim_header_sid || ')');
    END pr_clm_pa_rec_1;
-- FORALL SAVE EXCEPTIONS Approach 3
    PROCEDURE pr_clm_pa_rec_2 (
        p_actual_rec_no         IN NUMBER,
        p_rx_claim_header_sid   IN NUMBER,
        p_interface_run_sid     IN NUMBER,
        p_err_code              OUT VARCHAR2,
        p_err_msg               OUT VARCHAR2
    )
        IS
    TYPE typ_clm_pa_rec IS
        TABLE OF ist_ili5200_clm_pa_rec%rowtype;
    t_clm_pa_rec typ_clm_pa_rec;
    e_dml_errors EXCEPTION;
    pragma exception_init (e_dml_errors, -24381);
    BEGIN
        p_err_code := '0';
        p_err_msg := 'Success';
        SELECT
            *
        BULK COLLECT INTO
            t_clm_pa_rec
        FROM
            ist_ili5200_clm_pa_rec
        WHERE
            actual_rec_no = p_actual_rec_no
            AND   ff_stg_sid = p_interface_run_sid;

        FORALL k IN t_clm_pa_rec.first..t_clm_pa_rec.last SAVE EXCEPTIONS
            INSERT INTO ad_rx_p_clm_hdr_prior_athrztn (
                rx_clm_hdr_prior_athrztn_sid,
                rx_claim_header_sid,
                prior_athrztn_type_lkpcd,
                prior_athrztn_nmbr,
                prior_athrztn_sbmtd_nmbr,
                prior_athrztn_asgnd_nmbr,
                created_by,
                created_date,
                modified_by,
                modified_date,
                pa_step_order,
                auto_pa_code,
                pa_type
            ) VALUES (
                ad_rx_p_clm_hdr_pa_seq.NEXTVAL,
                p_rx_claim_header_sid,
                NULL,
                t_clm_pa_rec(k).prior_auth_number,
                NULL,
                NULL,
                1,
                SYSDATE,
                1,
                SYSDATE,
                NULL,
                t_clm_pa_rec(k).auto_pa_cd,
                t_clm_pa_rec(k).pa_type
            );

    EXCEPTION
        WHEN e_dml_errors THEN
          p_err_code:=SQLCODE;
          p_err_msg := 'Error in Bulk Insert/Update/Delete ' || sqlerrm;

          pk_db_error.pr_log( p_object_name => 'pk_rules_test_with_stndrd', p_sub_routine_name => 'pr_clm_pa_rec_2', p_error_code => p_err_code, p_error_msg => p_err_msg, p_error_details => p_err_msg || ' - p_rx_claim_header_sid ('|| p_rx_claim_header_sid || ')' );

        WHEN OTHERS THEN
            p_err_code := sqlcode;
            p_err_msg := 'Error in pr_clm_pa_rec_1 -:'
            || substr(sqlerrm,1,200)
            || dbms_utility.format_error_backtrace ();

            pk_db_error.pr_log(p_object_name => 'pk_rules_test_with_stndrd',p_sub_routine_name => 'pr_clm_pa_rec_2',p_error_code => p_err_code,p_error_msg => p_err_msg,p_error_details => p_err_msg || ' - p_rx_claim_header_sid (' || p_rx_claim_header_sid || ')');
    END pr_clm_pa_rec_2;
END pk_rules_test_with_stndrd;
/