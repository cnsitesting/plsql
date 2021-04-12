create or replace PACKAGE pk_rules_test_without_stndrd
AS
/******************************************************************************
   NAME:       PK_RULES_TEST_WITHOUT_STNDRD
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
END pk_rules_test_without_stndrd;
/
create or replace PACKAGE BODY pk_rules_test_without_stndrd
AS
/******************************************************************************
   NAME:       PK_RULES_TEST_WITHOUT_STNDRD
   PURPOSE:   To validate Sonarqube Rule: BadRaiseApplicationErrorUsageCheck, FunctionLastStatementReturnCheck, VariableRedeclaration, ForallStatementShouldUseSaveExceptionsClause

   REVISIONS:
   Ver       Date          Author         Description
   -------  ------------  -------------  ------------------------------------
   1.0       04/07/2021      Sridevi        Created this procedure.
******************************************************************************/
-- No Return statement at the end of Function Scenario 1
    FUNCTION fn_gen_file_id (
        p_previous_code IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_voucher_num   VARCHAR2(32767);
        v_exhaust       VARCHAR2(32767);
        v_alpha         VARCHAR2(32767);
        v_number        NUMBER(38);
        out_of_bound EXCEPTION;
        /* Redeclared variables but not used */
        v_cnt           NUMBER;
        v_cnt           NUMBER;
    BEGIN
        IF p_previous_code IS NULL THEN
            SELECT
                'A00001'
            INTO v_voucher_num
            FROM
                dual;
            RETURN v_voucher_num;
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
            RETURN v_voucher_num;
        END IF;
    EXCEPTION
        WHEN out_of_bound THEN
            raise_application_error(-1, 'Voucher number out of bound.'); -- Raise application error range not between 20000 and 20999
    END fn_gen_file_id;
-- No Return statement at the end of Function Scenario 2
   FUNCTION fn_validate_cci_mod_ind (p_mdfr_csv            IN VARCHAR2,
                                     p_service_from_date   IN VARCHAR2,
                                     p_service_to_date     IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_cnt   NUMBER;
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
         RETURN 'Y';
      ELSE
         RETURN 'N';
      END IF;
   END fn_validate_cci_mod_ind;
-- No Return statement at the end of Function Scenario 3
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
            RETURN l_next_nmbr;
         END IF;
      END LOOP;
   END fn_getpacrtfctnnmbr;
-- FORALL SAVE EXCEPTIONS
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

        FORALL k IN t_clm_pa_rec.first..t_clm_pa_rec.last
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
        WHEN OTHERS THEN
            p_err_code := sqlcode;
            p_err_msg := 'Error in pr_clm_pa_rec -:'
            || substr(sqlerrm,1,200)
            || dbms_utility.format_error_backtrace ();

            pk_db_error.pr_log(p_object_name => 'pk_rules_test_with_stndrd',p_sub_routine_name => 'pr_clm_pa_rec',p_error_code => p_err_code,p_error_msg => p_err_msg,p_error_details => p_err_msg || ' - p_rx_claim_header_sid (' || p_rx_claim_header_sid || ')');
    END pr_clm_pa_rec;
END pk_rules_test_without_stndrd;
/