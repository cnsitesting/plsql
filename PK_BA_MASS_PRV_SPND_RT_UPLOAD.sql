create or replace PACKAGE pk_ba_mass_prv_spnd_rt_upload IS
  /*---------------------------------------------------------------------------------
  Name  :   pk_ba_mass_prv_spnd_rt_upload
  Purpose : Upload the Provider spending limits to the table
  Revisions :
  Ver        Date            Author                  Description
  ---------  ----------     ---------------        -------------------------
  1.0       09/23/2019    Vairamuthu Raja       Initial creation
  Parameters :
  Input  : Input to the pr_main procedure is upld_btch_fl_instance_sid
  Output  :
  Return  :
  Called by : Java Screens
  Assumptions :
  Notes  :
  ------------------------------------------------------------------------------------*/
    c_rate_upld_btch_job_sid batch_job.batch_job_sid%TYPE := 686;
    e_generated_exception EXCEPTION;
    c_created_by CONSTANT NUMBER(15,0) := 1;
    c_sysdate DATE := SYSDATE;
    g_data VARCHAR2(4000);
	c_slmax_limit constant number := 1000000000;
    c_slmin_limit constant number := 0;
    TYPE rec_mass_upload IS RECORD ( p_recordno VARCHAR2(50),
    p_tax_idntfctn_nmbr VARCHAR2(50),
    p_group_code VARCHAR2(50),
    p_spndng_limit VARCHAR2(50),
    p_from_date VARCHAR2(50),
    p_to_date VARCHAR2(50),
    p_action VARCHAR2(50) );
    PROCEDURE pr_main (
        p_upld_btch_fl_instance_sid   IN upload_batch_file_instance.upload_batch_file_instance_sid%TYPE,
        p_usr_acct_sid                IN user_account.user_acct_sid%TYPE,
        p_batch_instance_sid          OUT batch_instance.batch_instance_sid%TYPE,
        p_rec_count                   OUT VARCHAR2,
        p_success_count               OUT VARCHAR2,
        p_failure_count               OUT VARCHAR2,
        p_batch_id                    OUT VARCHAR2,
        p_error_code                  OUT VARCHAR2,
        p_error_msg                   OUT VARCHAR2
    );

    PROCEDURE pr_logexcptn (
        p_batch_instance_sid   IN batch_instance.batch_instance_sid%TYPE,
        p_err_nmbr             IN batch_instance_error.batch_error_code%TYPE,
        p_err_msg              IN batch_instance_error.error_msg%TYPE,
        p_record_rfrnc         IN batch_instance_error.record_rfrnc%TYPE,
        p_module               IN batch_instance_error.prcdr_section%TYPE,
        p_created_by           IN batch_instance_error.created_by%TYPE,
        p_created_date         IN DATE
    );

END pk_ba_mass_prv_spnd_rt_upload;

/

create or replace PACKAGE BODY pk_ba_mass_prv_spnd_rt_upload IS
  /*---------------------------------------------------------------------------------
  Name  :   pk_ba_mass_prv_spnd_rt_upload
  Purpose : Upload the Provider spending limits to the table
  Revisions :
  Ver        Date            Author                  Description
  ---------  ----------     ---------------        -------------------------
  1.0       09/23/2019    Vairamuthu Raja       Initial creation
  Parameters :
  Input  : Input to the pr_main procedure is upld_btch_fl_instance_sid
  Output  :
  Return  :
  Called by : Java Screens
  Assumptions:
  Notes  :
  ------------------------------------------------------------------------------------*/

    PROCEDURE pr_logexcptn (
        p_batch_instance_sid   IN batch_instance.batch_instance_sid%TYPE,
        p_err_nmbr             IN batch_instance_error.batch_error_code%TYPE,
        p_err_msg              IN batch_instance_error.error_msg%TYPE,
        p_record_rfrnc         IN batch_instance_error.record_rfrnc%TYPE,
        p_module               IN batch_instance_error.prcdr_section%TYPE,
        p_created_by           IN batch_instance_error.created_by%TYPE,
        p_created_date         IN DATE
    ) IS
        PRAGMA autonomous_transaction;
        v_cnt                NUMBER(3);
        v_batchinstanceerr   batch_instance_error%rowtype;
    BEGIN
        SELECT
            COUNT(*)
        INTO
            v_cnt
        FROM
            batch_error_code
        WHERE
            batch_job_sid = c_rate_upld_btch_job_sid
            AND   batch_error_code = p_err_nmbr
            AND   oprtnl_flag = 'A';

        IF
            v_cnt = 0
        THEN
            RAISE e_generated_exception;
        ELSE
            v_batchinstanceerr.batch_error_code := p_err_nmbr;
        END IF;

        SELECT
            batch_instance_error_seq.NEXTVAL
        INTO
            v_batchinstanceerr.batch_instance_error_sid
        FROM
            dual;

        v_batchinstanceerr.batch_instance_sid := p_batch_instance_sid;
        v_batchinstanceerr.prcdr_section := upper(p_module);
        v_batchinstanceerr.error_msg := p_err_msg;
        v_batchinstanceerr.created_by := c_created_by;
        v_batchinstanceerr.created_date := p_created_date;
        v_batchinstanceerr.record_rfrnc := p_record_rfrnc;
        INSERT INTO batch_instance_error VALUES v_batchinstanceerr;

        COMMIT;
    EXCEPTION
        WHEN e_generated_exception THEN
            return;
    END pr_logexcptn;

    PROCEDURE pr_get_batch_id (
        p_batch_id IN OUT VARCHAR2,
        p_err_code IN OUT VARCHAR2,
        p_err_msg IN OUT VARCHAR2
    ) IS
        v_batch_id   VARCHAR2(12);
    BEGIN
        v_batch_id := TO_CHAR(SYSDATE,'YYYY')
        || TO_CHAR(SYSDATE,'DDD')
        || '%';

        BEGIN
            SELECT
                a.batch_idntfr + 1
            INTO
                p_batch_id
            FROM
                (
                    SELECT
                        batch_idntfr
                    FROM
                        prvdr_rate_spndng_limit
                    WHERE
                        batch_idntfr LIKE v_batch_id
                    ORDER BY
                        batch_idntfr DESC
                ) a
            WHERE
                ROWNUM = 1;

        EXCEPTION
            WHEN OTHERS THEN
                p_batch_id := TO_CHAR(SYSDATE,'YYYY')
                || TO_CHAR(SYSDATE,'DDD')
                || '001';
        END;

    END pr_get_batch_id;

    PROCEDURE pr_update_status (
        p_success_flag                IN CHAR,
        p_batch_instance_sid          IN NUMBER,
        p_upld_btch_fl_instance_sid   IN NUMBER,
        p_number_of_records           IN NUMBER,
        p_number_of_err_recs          IN NUMBER
    )
        IS
    BEGIN
        IF
            p_success_flag = 'N'
        THEN
            UPDATE upload_batch_file_instance
                SET
                    record_count = nvl(p_number_of_records,0),
                    record_success_count = nvl(p_number_of_records,0) - nvl(p_number_of_err_recs,0),
                    record_error_count = nvl(p_number_of_err_recs,0),
                    current_file_status_cid = 6
            WHERE
                upload_batch_file_instance_sid = p_upld_btch_fl_instance_sid;

        ELSE
            UPDATE upload_batch_file_instance
                SET
                    record_count = nvl(p_number_of_records,0),
                    record_success_count = nvl(p_number_of_records,0) - nvl(p_number_of_err_recs,0),
                    record_error_count = nvl(p_number_of_err_recs,0),
                    current_file_status_cid = 7
            WHERE
                upload_batch_file_instance_sid = p_upld_btch_fl_instance_sid;

        END IF;
    END pr_update_status;

    PROCEDURE pr_validate_header (
        p_rec_mass_upload   IN rec_mass_upload,
        p_err_code IN OUT VARCHAR2,
        p_err_msg IN OUT VARCHAR2
    ) IS
        v_module   VARCHAR2(500) := 'pk_ba_mass_prv_spnd_rt_upload.pr_validate_header';
    BEGIN
        IF
            ( upper(p_rec_mass_upload.p_tax_idntfctn_nmbr) <> 'TAX ID' OR upper(p_rec_mass_upload.p_group_code) <> 'GROUP CODE' OR upper(p_rec_mass_upload
.p_spndng_limit) <> 'SPENDING LIMIT' OR upper(p_rec_mass_upload.p_from_date) <> 'START DATE' OR upper(p_rec_mass_upload.p_to_date) <> 'END DATE'
OR upper(p_rec_mass_upload.p_action) <> 'ACTION' )
        THEN
            p_err_code := '30012';
            p_err_msg := 'Invalid Header Names';
            return;
        ELSIF ( upper(p_rec_mass_upload.p_tax_idntfctn_nmbr) IS NULL OR upper(p_rec_mass_upload.p_group_code) IS NULL OR upper(p_rec_mass_upload.p_spndng_limit
) IS NULL OR upper(p_rec_mass_upload.p_from_date) IS NULL OR upper(p_rec_mass_upload.p_to_date) IS NULL OR upper(p_rec_mass_upload.p_action) IS
NULL ) THEN
            p_err_code := '30012';
            p_err_msg := 'Invalid Header Names';
            return;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := sqlcode;
            p_err_msg := sqlerrm;
            pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_VALIDATE_HEADER',p_err_code,'RAISE EXCEPTION IN VALIDATE HEADER',p_err_msg
);
    END pr_validate_header;

    PROCEDURE pr_assign_values (
        p_rec_data          IN VARCHAR2,
        p_delimiter         IN VARCHAR2,
        p_rec_mass_upload   OUT rec_mass_upload,
        p_recno             IN NUMBER,
        p_errcnt IN OUT NUMBER
    ) IS
        v_string    VARCHAR2(50);
        v_module    VARCHAR2(100);
        v_err_msg   VARCHAR2(300);
    BEGIN
        v_module := 'pk_ba_mass_prv_spnd_rt_upload.pr_assign_values';
        p_rec_mass_upload.p_recordno := p_recno;
        FOR v_fields IN (
            SELECT
                ROWNUM row_num,
                replace(regexp_substr(replace(p_rec_data,',',',Â¥'),'[^'
                || p_delimiter
                || ']+',1,level),'Â¥','') val
            FROM
                dual
            CONNECT BY
                regexp_substr(replace(p_rec_data,',',',Â¥'),'[^'
                || p_delimiter
                || ']+',1,level) IS NOT NULL
        ) LOOP
            v_string := v_fields.val;
            IF
                upper(v_string) = 'NULL'
            THEN
                v_string := NULL;
            END IF;
            IF
                MOD(v_fields.row_num,6) = 1
            THEN
                p_rec_mass_upload.p_tax_idntfctn_nmbr := trim(v_string);
            ELSIF MOD(v_fields.row_num,6) = 2 THEN
                p_rec_mass_upload.p_group_code := trim(v_string);
            ELSIF MOD(v_fields.row_num,6) = 3 THEN
                p_rec_mass_upload.p_spndng_limit := trim(v_string);
            ELSIF MOD(v_fields.row_num,6) = 4 THEN
                p_rec_mass_upload.p_from_date := trim(v_string);
            ELSIF MOD(v_fields.row_num,6) = 5 THEN
                p_rec_mass_upload.p_to_date := trim(v_string);
            ELSIF MOD(v_fields.row_num,6) = 0 THEN
                p_rec_mass_upload.p_action := trim(v_string);
            END IF;

        END LOOP;

    EXCEPTION
        WHEN e_generated_exception THEN
            return;
        WHEN OTHERS THEN
            pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_ASSIGN_VALUES','12419','RAISE EXCEPTION IN ASSIGN VALUES',dbms_utility.format_error_backtrace
()
            || ' '
            || sqlerrm);
    END pr_assign_values;
--This procedure is used to Validate the field Values

    PROCEDURE pr_validate_clob (
        p_batch_instance_sid         IN batch_instance.batch_instance_sid%TYPE,
        p_rec_mass_upload            IN OUT rec_mass_upload,
        p_recno                      IN VARCHAR2,
        p_prvdr_rate_spndng_period   OUT prvdr_rate_spndng_period%rowtype,
        p_prvdr_rate_spndng_limit    OUT prvdr_rate_spndng_limit%rowtype,
        p_processed                  OUT NUMBER,
        p_err_code IN OUT VARCHAR2,
        p_err_msg IN OUT VARCHAR2
    ) IS

        v_module         VARCHAR2(500) := 'pk_ba_mass_prv_spnd_rt_upload.pr_validate_clob';
        v_rate           NUMBER(12,2);
        v_l              NUMBER(2);
        v_count          PLS_INTEGER;
        v_status_cid     NUMBER(1);
        v_start_year     NUMBER(4);
        v_end_year       NUMBER(4);
        v_group_cid      NUMBER(10);
        v_spndng_limit   NUMBER(15,2);
        v_start_date     VARCHAR2(2);
        v_start_month    VARCHAR2(2);
    BEGIN
        p_processed := 1;
        IF
            p_rec_mass_upload.p_tax_idntfctn_nmbr IS NULL --Validating Tax Id
        THEN
            pr_logexcptn(p_batch_instance_sid,30001,'Please enter a value for Tax ID',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_rec_mass_upload.p_group_code IS NULL -- Validating Group Code
        THEN
            pr_logexcptn(p_batch_instance_sid,30002,'Please enter a value for Group Code',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_rec_mass_upload.p_spndng_limit IS NULL --Validating Spending Limit
        THEN
            pr_logexcptn(p_batch_instance_sid,30003,'Please enter a value for Spending Limit',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_rec_mass_upload.p_from_date IS NULL --Validating Start Date
        THEN
            pr_logexcptn(p_batch_instance_sid,30004,'Please enter a value for Start Date.',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_rec_mass_upload.p_to_date IS NULL --Validating End Date
        THEN
            pr_logexcptn(p_batch_instance_sid,30005,'Please enter a value for End Date.',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_rec_mass_upload.p_action IS NULL --Validating Action
        THEN
            pr_logexcptn(p_batch_instance_sid,30022,'Please enter a value for Action.',p_recno,v_module,c_created_by,c_sysdate);
            p_processed := 0;
        END IF;

        IF
            p_processed = 1 AND p_rec_mass_upload.p_tax_idntfctn_nmbr IS NOT NULL
        THEN
      --Validating the Tax Identification Number is valid and Assigning Tax Id
            BEGIN
                SELECT DISTINCT
                    tax_idntfctn_nmbr
                INTO
                    p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                FROM
                    tax_entity_detail
                WHERE
                    tax_idntfctn_nmbr = p_rec_mass_upload.p_tax_idntfctn_nmbr
                    AND   status_cid = 2
                    AND   oprtnl_flag = 'A'
                    AND   trunc(SYSDATE) BETWEEN from_date AND TO_DATE;

            EXCEPTION
                WHEN OTHERS THEN
                    pr_logexcptn(p_batch_instance_sid,30006,'Please enter a valid value for Tax ID.',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
            END;
        END IF;

        IF
             p_processed = 1 AND p_rec_mass_upload.p_group_code IS NOT NULL
        THEN
      --Validating the Group Code is Valid and Assigning Group Code
            BEGIN
                SELECT DISTINCT
                    g.group_cid
                INTO
                    p_prvdr_rate_spndng_period.group_cid
                FROM
                    groups g,
                    group_status gs,
                    group_category gc
                WHERE
                    g.group_code = p_rec_mass_upload.p_group_code
                    AND   g.group_cid = gs.group_cid
                    AND   gs.status_type_cid = 1
                    AND   gs.status_cid = 2
                    AND   gs.oprtnl_flag = 'A'
                    AND   SYSDATE BETWEEN gs.from_date AND gs.TO_DATE
                    AND   g.group_ctgry_cid = gc.group_ctgry_cid
                    AND   gc.group_ctgry_cid = 190
                    AND   gc.oprtnl_flag = 'A';

            EXCEPTION
                WHEN OTHERS THEN
                    pr_logexcptn(p_batch_instance_sid,30007,'Group Code was not found in the System.',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                    NULL;
            END;
        END IF;

        IF
            p_processed = 1  AND  p_rec_mass_upload.p_spndng_limit IS NOT NULL
        THEN
      --Validating the format of the Spending Limit Field (Eg., 98.98, 1.76, 899.00 etc.,) and Assignign Spending Limit
            BEGIN
                SELECT
                    p_rec_mass_upload.p_spndng_limit
                INTO
                    p_prvdr_rate_spndng_limit.spndng_limit_amt
                FROM
                    dual
                WHERE
                    REGEXP_LIKE ( p_rec_mass_upload.p_spndng_limit,
                    '(^-?[0-9]*\.[0-9]{2}$)' );

            EXCEPTION
                WHEN no_data_found THEN
                    pr_logexcptn(p_batch_instance_sid,30008,'Invalid Format for Spending Limit. Value must be numeric and contain 2 decimal places.',
p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
            END;
        END IF;
        
        
IF
            p_processed = 1 AND p_rec_mass_upload.p_spndng_limit IS NOT NULL
        THEN
            BEGIN
              IF to_number(p_rec_mass_upload.p_spndng_limit) < c_slmin_limit THEN 
                pr_logexcptn(p_batch_instance_sid,30014,'Spending Limit value cannot be less than 0',p_recno,v_module,c_created_by,c_sysdate);
                p_processed := 0;
              END IF;
            END;
        END IF;
        
         IF
            p_processed = 1 AND p_rec_mass_upload.p_spndng_limit IS NOT NULL
        THEN
            BEGIN
              IF to_number(p_rec_mass_upload.p_spndng_limit) > c_slmax_limit THEN 
                pr_logexcptn(p_batch_instance_sid,30023,'Spending Limit value cannot be greater than 1000000000.',p_recno,v_module,c_created_by,c_sysdate);
                p_processed := 0;
              END IF;
            END;
        END IF; 

        IF
            p_rec_mass_upload.p_from_date IS NOT NULL
        THEN
            BEGIN
        --Validating Start Date must correspond to the Fiscal Year and must be in MM/DD/YYYY format.
                p_prvdr_rate_spndng_limit.from_date := TO_DATE(p_rec_mass_upload.p_from_date,'MM/DD/YYYY');
            EXCEPTION
                WHEN OTHERS THEN
                    pr_logexcptn(p_batch_instance_sid,30009,'Start Date must correspond to the Fiscal Year and must be in MM/DD/YYYY format.',p_recno
,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
            END;
        END IF;

        IF
           p_processed = 1 AND  p_prvdr_rate_spndng_limit.from_date IS NOT NULL
        THEN
            BEGIN
                IF
                    ( TO_DATE(trim(p_rec_mass_upload.p_from_date),'MM/DD/YYYY') < TO_DATE('01/01/1901','MM/DD/YYYY') )
                THEN
                    pr_logexcptn(p_batch_instance_sid,30017,'Start Date Min',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            END;
        END IF;

        IF
           p_processed = 1 AND  p_prvdr_rate_spndng_limit.from_date IS NOT NULL
        THEN
            BEGIN
                IF
                    ( TO_DATE(trim(p_rec_mass_upload.p_from_date),'MM/DD/YYYY') > TO_DATE('12/31/2998','MM/DD/YYYY') )
                THEN
                    pr_logexcptn(p_batch_instance_sid,30018,'Start Date Max',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            END;
        END IF;

        IF
            p_processed = 1 AND p_rec_mass_upload.p_to_date IS NOT NULL
        THEN
            BEGIN
        --Validating Start Date must correspond to the Fiscal Year and must be in MM/DD/YYYY format.
                p_prvdr_rate_spndng_limit.TO_DATE := TO_DATE(p_rec_mass_upload.p_to_date,'MM/DD/YYYY');
            EXCEPTION
                WHEN OTHERS THEN
                    pr_logexcptn(p_batch_instance_sid,30010,'End Date must correspond to the Fiscal Year and must be in MM/DD/YYYY format.',p_recno
,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
            END;
        END IF;

        IF
            p_processed = 1 AND p_rec_mass_upload.p_to_date IS NOT NULL
        THEN
            BEGIN
                IF
                    ( TO_DATE(trim(p_rec_mass_upload.p_to_date),'MM/DD/YYYY') < TO_DATE('01/01/1900','MM/DD/YYYY') )
                THEN
                    pr_logexcptn(p_batch_instance_sid,30021,'End Date Min',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            END;
        END IF;

        IF
            p_processed = 1 AND TRIM(p_rec_mass_upload.p_to_date) IS NOT NULL
        THEN
            BEGIN
                IF
                    ( TO_DATE(trim(p_rec_mass_upload.p_to_date),'MM/DD/YYYY') > TO_DATE('12/31/2999','MM/DD/YYYY') )
                THEN
                    pr_logexcptn(p_batch_instance_sid,30020,'End Date Max',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            END;
        END IF;

        IF
           p_processed = 1 AND  p_rec_mass_upload.p_from_date IS NOT NULL AND p_rec_mass_upload.p_to_date IS NOT NULL
        THEN
            BEGIN
                IF
                    ( TO_DATE(trim(p_rec_mass_upload.p_from_date),'MM/DD/YYYY') > TO_DATE(trim(p_rec_mass_upload.p_to_date),'MM/DD/YYYY') )
                THEN
                    pr_logexcptn(p_batch_instance_sid,30011,'Start Date Greater Than End Date',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            END;
        END IF;

        IF
            p_processed = 1 AND p_prvdr_rate_spndng_limit.from_date IS NOT NULL
        THEN
            BEGIN
                IF
                    trunc(p_prvdr_rate_spndng_limit.from_date) = trunc(SYSDATE)
                THEN
                    BEGIN
                        SELECT
                            fscl_start_date,
                            add_months(fscl_start_date,12) - 1 AS fscl_end_date
                        INTO
                            p_prvdr_rate_spndng_period.from_date,p_prvdr_rate_spndng_period.TO_DATE
                        FROM
                            (
                                SELECT
                                        CASE
                                            WHEN EXTRACT(MONTH FROM TO_DATE(p_rec_mass_upload.p_from_date,'MM/DD/YYYY') ) BETWEEN 1 AND 6 THEN add_months(trunc(TO_DATE(p_rec_mass_upload
.p_from_date,'MM/DD/YYYY'),'year'),-6)
                                            ELSE add_months(trunc(TO_DATE(p_rec_mass_upload.p_from_date,'MM/DD/YYYY'),'year'),6)
                                        END
                                    AS fscl_start_date
                                FROM
                                    dual
                            );

                        IF
                            ( trunc(p_prvdr_rate_spndng_limit.TO_DATE) > trunc(p_prvdr_rate_spndng_period.TO_DATE) ) OR ( trunc(p_prvdr_rate_spndng_limit.TO_DATE) <=
trunc(p_prvdr_rate_spndng_period.from_date) )
                        THEN
                            pr_logexcptn(p_batch_instance_sid,30010,'End Date is Invalid',p_recno,v_module,c_created_by,c_sysdate);
                            p_processed := 0;
                        ELSE
                            p_prvdr_rate_spndng_limit.TO_DATE := p_prvdr_rate_spndng_period.TO_DATE;
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pr_logexcptn(p_batch_instance_sid,30016,'Start Date should be Today''s date',p_recno,v_module,c_created_by,c_sysdate);
                            p_processed := 0;
                    END;

                ELSE
                    pr_logexcptn(p_batch_instance_sid,30016,'Start Date should be Today''s date',p_recno,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        IF
            p_processed = 1 AND upper(p_rec_mass_upload.p_action) != 'INACTIVATE'
        THEN
            BEGIN
                SELECT
                    COUNT(*)
                INTO
                    v_l
                FROM
                    prvdr_rate_spndng_period prsl,
                    prvdr_rate_spndng_limit prsld,
                    status sts,
                    status_type ststy
                WHERE
                    prsl.prvdr_rate_spndng_period_sid = prsld.prvdr_rate_spndng_period_sid
                    AND   sts.status_type_cid = ststy.status_type_cid
                    AND   prsld.status_type_cid = ststy.status_type_cid
                    AND   prsld.status_cid = sts.status_cid
                    AND   prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                    AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                    AND   trunc(prsld.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                    AND   trunc(prsl.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                    AND   prsld.status_cid = 1 -- IN Review Status
                    AND   prsl.oprtnl_flag = 'A'
                    AND   prsld.oprtnl_flag = 'A';

                IF
                    v_l > 0
                THEN
                    pr_logexcptn(p_batch_instance_sid,30015,'In Review record already exists for combination of Tax ID, Group Code in fiscal year',p_recno
,v_module,c_created_by,c_sysdate);
                    p_processed := 0;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    p_processed := 0;
            END;

            IF
                p_processed = 1
            THEN
                IF
                    p_prvdr_rate_spndng_period.tax_idntfctn_nmbr IS NOT NULL AND p_prvdr_rate_spndng_period.group_cid IS NOT NULL AND p_prvdr_rate_spndng_period
.TO_DATE IS NOT NULL AND p_prvdr_rate_spndng_limit.from_date IS NOT NULL AND p_prvdr_rate_spndng_limit.TO_DATE IS NOT NULL AND p_prvdr_rate_spndng_limit
.spndng_limit_amt IS NOT NULL
                THEN
          --Validating Spending Limit exists for given data (Tax Id, Group Code, Start Date, End Date and Spending Limit)
                    BEGIN
                        v_l := 0;
                        SELECT
                            COUNT(*)
                        INTO
                            v_l
                        FROM
                            prvdr_rate_spndng_period prsl,
                            prvdr_rate_spndng_limit prsld,
                            status sts,
                            status_type ststy
                        WHERE
                            prsl.prvdr_rate_spndng_period_sid = prsld.prvdr_rate_spndng_period_sid
                            AND   sts.status_type_cid = ststy.status_type_cid
                            AND   prsld.status_type_cid = ststy.status_type_cid
                            AND   prsld.status_cid = sts.status_cid
                            AND   prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                            AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                            AND   trunc(prsld.from_date) = p_prvdr_rate_spndng_limit.from_date
                            AND   trunc(prsld.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                            AND   trunc(prsl.TO_DATE) = p_prvdr_rate_spndng_period.TO_DATE
                            AND   prsld.spndng_limit_amt = p_prvdr_rate_spndng_limit.spndng_limit_amt
                            AND   prsld.status_cid IN (
                                1,
                                2
                            )
                            AND   prsl.oprtnl_flag = 'A'
                            AND   prsld.oprtnl_flag = 'A';

                        IF
                            v_l > 0
                        THEN
                            pr_logexcptn(p_batch_instance_sid,30000,'Spending Limit exists for given criteria, it cannot be duplicated.',p_recno,v_module,c_created_by
,c_sysdate);
                            p_processed := 0;
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL;
                    END;

                END IF;

            END IF;

            IF
                p_processed = 1 AND p_prvdr_rate_spndng_period.tax_idntfctn_nmbr IS NOT NULL AND p_prvdr_rate_spndng_period.group_cid IS NOT NULL AND p_prvdr_rate_spndng_period
.TO_DATE IS NOT NULL AND p_prvdr_rate_spndng_limit.from_date IS NOT NULL AND p_prvdr_rate_spndng_limit.TO_DATE IS NOT NULL
            THEN
        --Validating Tax ID, Group Code, Start Date, and End Date are unique -- Duplicate Spending Limit
                BEGIN
                    SELECT
                        COUNT(*)
                    INTO
                        v_l
                    FROM
                        prvdr_rate_spndng_period prsl,
                        prvdr_rate_spndng_limit prsld,
                        status sts,
                        status_type ststy
                    WHERE
                        prsl.prvdr_rate_spndng_period_sid = prsld.prvdr_rate_spndng_period_sid
                        AND   sts.status_type_cid = ststy.status_type_cid
                        AND   prsld.status_type_cid = ststy.status_type_cid
                        AND   prsld.status_cid = sts.status_cid
                        AND   prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                        AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                        AND   trunc(prsld.from_date) = p_prvdr_rate_spndng_limit.from_date
                        AND   trunc(prsld.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                        AND   trunc(prsl.TO_DATE) = p_prvdr_rate_spndng_period.TO_DATE
                        AND   prsld.status_cid = 2 -- Approved Status
                        AND   prsl.oprtnl_flag = 'A'
                        AND   prsld.oprtnl_flag = 'A';

                    IF
                        v_l > 0
                    THEN
                        p_prvdr_rate_spndng_limit.from_date := trunc(SYSDATE);
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;
            END IF;

        ELSE
            IF
                p_processed = 1
            THEN
                BEGIN
                    SELECT
                        COUNT(*)
                    INTO
                        v_l
                    FROM
                        prvdr_rate_spndng_period prsl,
                        prvdr_rate_spndng_limit prsld,
                        status sts,
                        status_type ststy
                    WHERE
                        prsl.prvdr_rate_spndng_period_sid = prsld.prvdr_rate_spndng_period_sid
                        AND   sts.status_type_cid = ststy.status_type_cid
                        AND   prsld.status_type_cid = ststy.status_type_cid
                        AND   prsld.status_cid = sts.status_cid
                        AND   prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                        AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                        AND   trunc(prsld.from_date) = p_prvdr_rate_spndng_limit.from_date
                        AND   trunc(prsld.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                        AND   trunc(prsl.TO_DATE) = p_prvdr_rate_spndng_period.TO_DATE
                        AND   prsld.status_cid = 2 -- Approved
                        AND   prsl.oprtnl_flag = 'A'
                        AND   prsld.oprtnl_flag = 'A';

                    IF
                        v_l = 0
                    THEN
                        pr_logexcptn(p_batch_instance_sid,30019,'No Matching Approved record found for Inactive',p_recno,v_module,c_created_by,c_sysdate)
;
                        p_processed := 0;
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;

            END IF;
        END IF;

    END pr_validate_clob;
--This Procedure is used to Insert or Update the Table p_prvdr_rate_spndng_limit

    PROCEDURE pr_insrt_prvdr_rate_spndng_lmt (
        p_upld_btch_fl_instance_sid   IN NUMBER,
        p_usr_acct_sid                IN user_account.user_acct_sid%TYPE,
        p_recno                       IN VARCHAR2,
        p_prvdr_rate_spndng_period IN OUT prvdr_rate_spndng_period%rowtype,
        p_prvdr_rate_spndng_limit IN OUT prvdr_rate_spndng_limit%rowtype,
        p_action                      IN VARCHAR2,
        p_batch_instance_sid          IN batch_instance.batch_instance_sid%TYPE,
        p_batch_id IN OUT VARCHAR2,
        p_err_code IN OUT VARCHAR2,
        p_err_msg IN OUT VARCHAR2
    ) IS

        v_status_cid                     NUMBER(1);
        v_l                              NUMBER(2);
        v_module                         VARCHAR2(500) := 'pk_ba_mass_prv_spnd_rt_upload.pr_validate_clob';
        v_prvdr_rate_spndng_period_sid   prvdr_rate_spndng_period.prvdr_rate_spndng_period_sid%TYPE;
        v_prvdr_rate_spndng_limit_sid    prvdr_rate_spndng_limit.prvdr_rate_spndng_limit_sid%TYPE;
        v_processed                      NUMBER(1);
    BEGIN
        v_processed := 1;
        IF
            upper(p_action) = 'INACTIVATE'
        THEN
            BEGIN
                SELECT
                    prsld.prvdr_rate_spndng_limit_sid
                INTO
                    v_prvdr_rate_spndng_limit_sid
                FROM
                    prvdr_rate_spndng_period prsl,
                    prvdr_rate_spndng_limit prsld,
                    status sts,
                    status_type ststy
                WHERE
                    prsl.prvdr_rate_spndng_period_sid = prsld.prvdr_rate_spndng_period_sid
                    AND   sts.status_type_cid = ststy.status_type_cid
                    AND   prsld.status_type_cid = ststy.status_type_cid
                    AND   prsld.status_cid = sts.status_cid
                    AND   prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                    AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                    AND   trunc(prsld.from_date) = p_prvdr_rate_spndng_limit.from_date
                    AND   trunc(prsld.TO_DATE) = p_prvdr_rate_spndng_limit.TO_DATE
                    AND   trunc(prsl.TO_DATE) = p_prvdr_rate_spndng_period.TO_DATE
                    AND   prsld.status_cid = 2 -- Approved
                    AND   prsl.oprtnl_flag = 'A'
                    AND   prsld.oprtnl_flag = 'A';

                UPDATE prvdr_rate_spndng_limit prsld
                    SET
                        prsld.oprtnl_flag = 'I'
                WHERE
                    prsld.prvdr_rate_spndng_limit_sid = v_prvdr_rate_spndng_limit_sid;

            EXCEPTION
                WHEN OTHERS THEN
                    v_processed := 0;
            END;

        ELSE
            IF
                v_processed = 1 AND p_action IS NOT NULL
            THEN
                BEGIN
                    SELECT DISTINCT
                        prsl.prvdr_rate_spndng_period_sid
                    INTO
                        v_prvdr_rate_spndng_period_sid
                    FROM
                        prvdr_rate_spndng_period prsl
                    WHERE
                        prsl.tax_idntfctn_nmbr = p_prvdr_rate_spndng_period.tax_idntfctn_nmbr
                        AND   prsl.group_cid = p_prvdr_rate_spndng_period.group_cid
                        AND   prsl.from_date = p_prvdr_rate_spndng_period.from_date
                        AND   prsl.TO_DATE = p_prvdr_rate_spndng_period.TO_DATE
                        AND   prsl.oprtnl_flag = 'A';

                EXCEPTION
                    WHEN OTHERS THEN
                        v_prvdr_rate_spndng_period_sid := NULL;
                END;

                IF
                    v_prvdr_rate_spndng_period_sid IS NULL --(new Record in prvdr_rate_spndng_period table)
                THEN
                    p_prvdr_rate_spndng_period.oprtnl_flag := 'A';
                    p_prvdr_rate_spndng_period.created_by := p_usr_acct_sid;
                    p_prvdr_rate_spndng_period.created_date := SYSDATE;
                    p_prvdr_rate_spndng_period.modified_by := p_usr_acct_sid;
                    p_prvdr_rate_spndng_period.modified_date := SYSDATE;
                    SELECT
                        prvdr_rate_spndng_period_seq.NEXTVAL
                    INTO
                        v_prvdr_rate_spndng_period_sid
                    FROM
                        dual;

                    p_prvdr_rate_spndng_period.prvdr_rate_spndng_period_sid := v_prvdr_rate_spndng_period_sid;
                    INSERT INTO prvdr_rate_spndng_period VALUES p_prvdr_rate_spndng_period;

                END IF;

                BEGIN
                    SELECT
                        prvdr_rate_spndng_limit_seq.NEXTVAL
                    INTO
                        p_prvdr_rate_spndng_limit.prvdr_rate_spndng_limit_sid
                    FROM
                        dual;

                    p_prvdr_rate_spndng_limit.prvdr_rate_spndng_period_sid := v_prvdr_rate_spndng_period_sid;
                    p_prvdr_rate_spndng_limit.status_type_cid := 1;
                    p_prvdr_rate_spndng_limit.status_cid := 1;
                    p_prvdr_rate_spndng_limit.remark := '';
                    p_prvdr_rate_spndng_limit.data_source_lkpcd := 'ENTRY';
                    p_prvdr_rate_spndng_limit.upload_date := SYSDATE;
                    p_prvdr_rate_spndng_limit.upload_batch_file_instance_sid := p_upld_btch_fl_instance_sid;
                    p_prvdr_rate_spndng_limit.batch_idntfr := p_batch_id;
                    p_prvdr_rate_spndng_limit.batch_instance_sid := p_batch_instance_sid;
                    p_prvdr_rate_spndng_limit.oprtnl_flag := 'A';
                    p_prvdr_rate_spndng_limit.created_by := p_usr_acct_sid;
                    p_prvdr_rate_spndng_limit.created_date := SYSDATE;
                    p_prvdr_rate_spndng_limit.modified_by := p_usr_acct_sid;
                    p_prvdr_rate_spndng_limit.modified_date := SYSDATE;
                    SELECT
                        file_name
                    INTO
                        p_prvdr_rate_spndng_limit.file_name
                    FROM
                        upload_batch_file_instance
                    WHERE
                        upload_batch_file_instance_sid = p_upld_btch_fl_instance_sid;

                    INSERT INTO prvdr_rate_spndng_limit VALUES p_prvdr_rate_spndng_limit;

                EXCEPTION
                    WHEN OTHERS THEN
                        p_err_code := '12419';
                        p_err_msg := substr(sqlerrm,1,200);
                        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','INSERT PROVIDER RATE SPENDING',p_err_code,'GENERAL EXCEPTION IN PR_INSRT_PRVDR_RATE_SPNDNG_LMT'
,p_err_msg);
                END;

            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := '12419';
            p_err_msg := substr(sqlerrm,1,200);
            pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','INSERT PROVIDER RATE SPENDING',p_err_code,'GENERAL EXCEPTION IN PR_INSRT_PRVDR_RATE_SPNDNG_LMT'
,p_err_msg);
    END pr_insrt_prvdr_rate_spndng_lmt;

    PROCEDURE pr_read_clob (
        p_upld_btch_fl_instance_sid   IN NUMBER,
        p_usr_acct_sid                IN user_account.user_acct_sid%TYPE,
        p_batch_instance_sid          IN batch_instance.batch_instance_sid%TYPE,
        p_conv_file_data              IN CLOB,
        p_rcrddlmtr                   IN VARCHAR2,
        p_delimiter                   IN VARCHAR2,
        p_created_by                  IN NUMBER,
        p_record_count                OUT NUMBER,
        p_success_count               OUT NUMBER,
        p_failure_count               OUT NUMBER,
        p_batch_id                    OUT VARCHAR2,
        p_err_code                    OUT VARCHAR2,
        p_err_msg                     OUT VARCHAR2
    ) AS

        v_errcnt                     NUMBER(10) := 0;
        v_rec_data                   VARCHAR2(4000);
        v_prgrm_name_in_file         VARCHAR2(100);
        v_header_validated           BOOLEAN := false;
        v_prvdr_rate_spndng_period   prvdr_rate_spndng_period%rowtype;
        v_prvdr_rate_spndng_limit    prvdr_rate_spndng_limit%rowtype;
        p_processed                  NUMBER;
        v_action                     VARCHAR2(20);
        v_recno                      NUMBER;
        p_rec_mass_upload            rec_mass_upload;
        v_insert_count               NUMBER(10) := 0;
        v_module                     VARCHAR2(500) := 'pk_ba_mass_prv_spnd_rt_upload.pr_read_clob';
    BEGIN
        p_err_code := pk_err_cnstn.c_err_cnstn_success;
        p_err_msg := 'Success';
        p_processed := 1;
        FOR v_rec IN (
            SELECT
                ROWNUM recordno,
                regexp_substr(p_conv_file_data,'[^'
                || p_rcrddlmtr
                || ']+',1,level) rowdata
            FROM
                dual
            CONNECT BY
                level <= length(regexp_substr(p_conv_file_data,'[^'
                || p_rcrddlmtr
                || ']+',1,level) )
        ) LOOP
		     SELECT regexp_replace(v_rec.rowdata,'^[,]{1}','null,',1,1)
				INTO v_rec_data
		     FROM dual; 
            v_recno := v_rec.recordno;
            pr_assign_values(v_rec_data,p_delimiter,p_rec_mass_upload,v_recno,v_errcnt);
            g_data := 'RECORD NUMBER--> '
            || p_rec_mass_upload.p_recordno
            || chr(10)
            || ' TAX IDENTIFICATION NUMBER--> '
            || p_rec_mass_upload.p_tax_idntfctn_nmbr
            || chr(10)
            || ' GROUP CID--> '
            || p_rec_mass_upload.p_group_code
            || chr(10)
            || ' SPENDING LIMIT--> '
            || p_rec_mass_upload.p_spndng_limit
            || chr(10)
            || ' FROM DATE--> '
            || p_rec_mass_upload.p_from_date
            || chr(10)
            || ' END DATE--> '
            || p_rec_mass_upload.p_to_date
            || chr(10)
            || ' ACTION--> '
            || p_rec_mass_upload.p_action;

            pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_READ_CLOB',6,'ALL VALUES DEPENDING UPON THE RECORD NUMBER',g_data);
            IF
                v_recno = 1
            THEN
                pr_validate_header(p_rec_mass_upload,p_err_code,p_err_msg);
                IF
                    p_err_code = '30012'
                THEN
                    return;
                END IF;
            ELSE
                pr_validate_clob(p_batch_instance_sid,p_rec_mass_upload,v_recno,v_prvdr_rate_spndng_period,v_prvdr_rate_spndng_limit,p_processed,
p_err_code,p_err_msg);

                g_data := 'RECORD NUMBER--> '
                || p_rec_mass_upload.p_recordno
                || chr(10)
                || ' TAX IDENTIFICATION NUMBER--> '
                || p_rec_mass_upload.p_tax_idntfctn_nmbr
                || chr(10)
                || ' GROUP CID--> '
                || p_rec_mass_upload.p_group_code
                || chr(10)
                || ' SPENDING LIMIT--> '
                || p_rec_mass_upload.p_spndng_limit
                || chr(10)
                || ' FROM DATE--> '
                || p_rec_mass_upload.p_from_date
                || chr(10)
                || ' END DATE--> '
                || p_rec_mass_upload.p_to_date
                || chr(10)
                || ' ACTION--> '
                || p_rec_mass_upload.p_action;

                pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_READ_CLOB',6,'ALL VALUES DEPENDING UPON THE RECORD NUMBER',g_data);
                IF
                    p_processed = 1 AND p_err_code = pk_err_cnstn.c_err_cnstn_success
                THEN
                    IF
                        v_insert_count = 0
                    THEN
                        pr_get_batch_id(p_batch_id,p_err_code,p_err_msg);
                    END IF;
                    pr_insrt_prvdr_rate_spndng_lmt(p_upld_btch_fl_instance_sid,p_usr_acct_sid,v_recno,v_prvdr_rate_spndng_period,v_prvdr_rate_spndng_limit
,p_rec_mass_upload.p_action,p_batch_instance_sid,p_batch_id,p_err_code,p_err_msg);

                    IF
                        p_err_code = 0
                    THEN
                        v_insert_count := v_insert_count + 1;
                    END IF;
                END IF;

            END IF;

        END LOOP;

        p_record_count := v_recno - 1;
        p_success_count := v_insert_count;
        p_failure_count := p_record_count - p_success_count;
        IF
            v_insert_count = 0
        THEN
            p_err_code := '20026';
            p_err_msg := 'File has no valid records';
            pr_logexcptn(p_batch_instance_sid,p_err_code,p_err_msg,0,v_module,c_created_by,c_sysdate);
            p_processed := 0;
            RAISE e_generated_exception;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_processed := 0;
            p_err_code := '12419';
            p_err_msg := dbms_utility.format_error_backtrace ()
            || ' '
            || sqlerrm;
    END pr_read_clob;

    PROCEDURE pr_main (
        p_upld_btch_fl_instance_sid   IN upload_batch_file_instance.upload_batch_file_instance_sid%TYPE,
        p_usr_acct_sid                IN user_account.user_acct_sid%TYPE,
        p_batch_instance_sid          OUT batch_instance.batch_instance_sid%TYPE,
        p_rec_count                   OUT VARCHAR2,
        p_success_count               OUT VARCHAR2,
        p_failure_count               OUT VARCHAR2,
        p_batch_id                    OUT VARCHAR2,
        p_error_code                  OUT VARCHAR2,
        p_error_msg                   OUT VARCHAR2
    ) IS

        v_batch_instance_sid           batch_instance.batch_instance_sid%TYPE;
        v_upload_batch_file_inst_sid   batch_file_data.upload_batch_file_instance_sid%TYPE;
        v_conv_file_data               batch_file_data.conv_file_data%TYPE;
        v_rcrddlmtr                    upload_type.record_separator%TYPE;
        v_delimiter                    upload_type.element_separator%TYPE;
        v_created_by                   upload_batch_file_instance.created_by%TYPE;
        v_rec_count                    NUMBER(10) := 0;
        v_success_count                NUMBER(10) := 0;
        v_failure_count                NUMBER(10) := 0;
        v_err_cnt                      PLS_INTEGER;
    BEGIN
        p_error_code := pk_err_cnstn.c_err_cnstn_success;
        p_error_msg := 'Success';
        g_data := p_upld_btch_fl_instance_sid;
        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',1,'BATCH STARTED * UPLOAD BATCH FILE INSTANCE SID',g_data);
        IF
            p_upld_btch_fl_instance_sid IS NULL
        THEN
            return;
        END IF;
        pk_batch_job_logging.pr_job_started('BA_MASS_PRV_SPND_RT_UPLOAD',v_batch_instance_sid,p_error_code,p_error_msg);
        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',2,'BEFORE EXECUTING QUERY TO FETCH BATCH_FILE_DATA','BEFORE EXECUTING QUERY TO FETCH BATCH_FILE_DATA'
);
        SELECT
            current_file_status_cid
        INTO
            g_data
        FROM
            upload_batch_file_instance ubfi
        WHERE
            ubfi.upload_batch_file_instance_sid = p_upld_btch_fl_instance_sid;

        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',5,'CURRENT_FILE_STATUS_CID',g_data);
        BEGIN
            SELECT
                bf.upload_batch_file_instance_sid,
                bf.conv_file_data,
                ut.record_separator rcrddlmtr,
                ut.element_separator delimiter,
                ubf.created_by
            INTO
                v_upload_batch_file_inst_sid,v_conv_file_data,v_rcrddlmtr,v_delimiter,v_created_by
            FROM
                batch_file_data bf,
                upload_type ut,
                upload_batch_file_instance ubf
            WHERE
                bf.oprtnl_flag = 'A'
                AND   ut.upload_type_cid = 22
                AND   ubf.upload_type_cid = ut.upload_type_cid
                AND   ut.oprtnl_flag = 'A'
                AND   ubf.oprtnl_flag = 'A'
                AND   ubf.upload_batch_file_instance_sid = p_upld_btch_fl_instance_sid
                AND   bf.upload_batch_file_instance_sid = ubf.upload_batch_file_instance_sid
            ORDER BY
                bf.upload_batch_file_instance_sid,
                bf.batch_file_data_sid;

            pr_read_clob(v_upload_batch_file_inst_sid,p_usr_acct_sid,v_batch_instance_sid,v_conv_file_data,v_rcrddlmtr,v_delimiter,v_created_by
,v_rec_count,v_success_count,v_failure_count,p_batch_id,p_error_code,p_error_msg);

            p_rec_count := v_rec_count;
            p_success_count := v_success_count;
            p_failure_count := v_failure_count;
            p_batch_instance_sid := v_batch_instance_sid;
            p_batch_id := p_batch_id;
            IF
                p_error_code <> 0
            THEN
                RAISE e_generated_exception;
            END IF;
        EXCEPTION
            WHEN no_data_found THEN
                pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',3,'UPLOAD_BATCH_FILE_INSTANCE.CURRENT_FILE_STATUS_CID WHEN NO DATA FOUND'
,g_data);
        END;

        IF
            p_error_code <> pk_err_cnstn.c_err_cnstn_success
        THEN
            pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',3,'AFTER EXECUTING PR_READ_CLOB','p_error_code='
            || p_error_code);
        END IF;

        g_data := 'Record Count --> '
        || v_rec_count
        || chr(10)
        || ' Error Record Count --> '
        || v_err_cnt;

        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',4,'RECORD COUNT AND ERROR RECORD COUNT',g_data);
        IF
            v_rec_count = 0 OR v_err_cnt > 0
        THEN
            pr_update_status('N',v_batch_instance_sid,p_upld_btch_fl_instance_sid,v_rec_count,v_err_cnt);
            COMMIT;
        ELSE
            pr_update_status('Y',v_batch_instance_sid,p_upld_btch_fl_instance_sid,v_rec_count,v_err_cnt);
            COMMIT;
        END IF;

        g_data := p_upld_btch_fl_instance_sid;
        pk_db_error.pr_log('PK_BA_MASS_PRV_SPND_RT_UPLOAD','PR_MAIN',5,'BATCH COMPLETED * UPLOAD BATCH FILE INSTANCE SID',g_data);
        pk_batch_job_logging.pr_job_completed(v_batch_instance_sid,p_error_code,p_error_msg);
    EXCEPTION
        WHEN e_generated_exception THEN
            return;
        WHEN OTHERS THEN
            p_error_code := '12419';
            p_error_msg := dbms_utility.format_error_backtrace ()
            || ' '
            || sqlerrm;
            pr_update_status('N',v_batch_instance_sid,p_upld_btch_fl_instance_sid,v_rec_count,v_err_cnt);
            pk_batch_job_logging.pr_job_failed(v_batch_instance_sid,p_error_code,p_error_msg);
            pk_db_error.pr_log('PK_BA_MASS_MBR_RATES_UPLOAD','PR_MAIN',5,'CURRENT_FILE_STATUS_CID',g_data);
    END pr_main;

END pk_ba_mass_prv_spnd_rt_upload;
/