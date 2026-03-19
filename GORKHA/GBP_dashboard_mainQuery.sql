CREATE OR ALTER PROCEDURE [dbo].[GBP_dashboard_mainQuery]
--DECLARE
        @DATE DATE,
        @TYPE VARCHAR(25) = '%',
        @ID VARCHAR(25) = '%',
        @DISTRIBUTOR VARCHAR(25) = '%',
        @REGION VARCHAR(100)= '%'
AS

--SELECT @DATE = GETDATE() 

---------------------------
--PARAMETER INITIALIZATION
---------------------------

DECLARE 
    @ad_date DATE = @DATE,
    @bs_date VARCHAR(10) ,
    @bs_month INT ,
    @bs_year INT

SELECT @bs_date = MITI , @bs_month = MAHINA , @bs_year = SAL  from DATEMITI_FULL where AD = @ad_date


------------------------------
--DATE CALCULATION (AD => BS )
------------------------------

DROP TABLE IF EXISTS #Date

SELECT MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_month_start,
       MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_month_end,
       MIN(CASE WHEN MAHINA = CASE WHEN @bs_month-1< 1 THEN 12 ELSE @bs_month - 1 END AND SAL = CASE WHEN @bs_month-1< 1 THEN @bs_year - 1 ELSE @bs_year -1 END THEN AD END) AS last_month_start,
       MAX(CASE WHEN MAHINA = CASE WHEN @bs_month-1< 1 THEN 12 ELSE @bs_month - 1 END AND SAL = CASE WHEN @bs_month -1<1 THEN @bs_year - 1 ELSE @bs_year-1 END THEN AD END) AS last_month_end,
       MIN(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_start,
       MAX(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_end,
       MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_Currentmonth_start,
       MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_currentmonth_end
INTO #Date
FROM DATEMITI_FULL;

-----------------------
--MAIN QUERY
-----------------------
IF (@ID in ('%','Admin'))
BEGIN

     SELECT [identifier], CAST([currents] as numeric (32,0)) [CURRENTS], CAST([old] as numeric (32,0)) [OLD], CAST([ACHIEVEMENTPERCENT] as numeric (32,0)) [ACHIEVEMENTPERCENT]
     FROM (
     
             SELECT 'Primary in Cases LM' [identifier], 
                     
                     SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],

                     SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],

                     ISNULL(CASE WHEN SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                  (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                            (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                             END ,0
                             ) [achievementPercent]
             FROM PURMAIN main
             JOIN PURPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             CROSS APPLY ( 
                           SELECT current_month_start, current_month_end, 
                                  last_month_start, last_month_end 
                           FROM #DATE
                          ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_month_start AND last_month_end OR main.TRNDATE BETWEEN current_month_start AND current_month_end)AND(@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Primary in Cases LY' [identifier], 
                     SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE 
                             WHEN SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                            (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                            END ,0
                           ) [achievementPercent]
             FROM PURMAIN main
             JOIN PURPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             CROSS APPLY ( 
                         SELECT current_year_start, current_year_end, 
                                last_year_Currentmonth_start, last_year_currentmonth_end 
                         FROM #DATE
                         ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_year_Currentmonth_start AND current_year_end )AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Secondary in Cases LM' [identifier], 
                     SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE WHEN SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                  (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                     THEN NULL
                     ELSE 
                         (SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, 
                                  (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                          / SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                    (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                     END, 0
                     ) [achievementPercent]
             FROM TRNMAIN main
             JOIN TRNPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             CROSS APPLY (
                         SELECT current_month_start, current_month_end, 
                                 last_month_start, last_month_end FROM #DATE
                          ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_month_start AND last_month_end OR main.TRNDATE BETWEEN current_month_start AND current_month_end)AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Secondary in Cases LY' [identifier],
                     SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1) ,0)) [old],
                     ISNULL(CASE 
                             WHEN SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                          (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, 
                                          (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                            (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)))
                         END ,0
                         ) [achievementPercent]
             FROM TRNMAIN main
             JOIN TRNPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             CROSS APPLY ( 
                         SELECT current_year_start, current_year_end, 
                                last_year_Currentmonth_start, last_year_currentmonth_end 
                         FROM #DATE
                         ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_year_Currentmonth_start AND current_year_end )AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
     )a

END

ELSE
BEGIN

     SELECT [identifier], CAST([currents] as numeric (32,0)) [CURRENTS], CAST([old] as numeric (32,0)) [OLD], CAST([ACHIEVEMENTPERCENT] as numeric (32,0)) [ACHIEVEMENTPERCENT]
     FROM (
     
             SELECT 'Primary in Cases LM' [identifier], 
                     SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE WHEN SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                  (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                            (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                             END ,0
                             ) [achievementPercent]
             FROM PURMAIN main
             JOIN PURPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             JOIN FN_UserHierarchy_Gorkha (@TYPE, @ID) hierarchy ON com.CompanyID = hierarchy.CompanyID
             CROSS APPLY ( 
                           SELECT current_month_start, current_month_end, 
                                  last_month_start, last_month_end 
                           FROM #DATE
                          ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_month_start AND last_month_end OR main.TRNDATE BETWEEN current_month_start AND current_month_end)AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Primary in Cases LY' [identifier], 
                     SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE 
                             WHEN SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, 
                                          (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                            (prod.REALQTY_IN - prod.REALQTY) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                            END ,0
                           ) [achievementPercent]
             FROM PURMAIN main
             JOIN PURPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             JOIN FN_UserHierarchy_Gorkha (@TYPE, @ID) hierarchy ON com.CompanyID = hierarchy.CompanyID
             CROSS APPLY ( 
                         SELECT current_year_start, current_year_end, 
                                last_year_Currentmonth_start, last_year_currentmonth_end 
                         FROM #DATE
                         ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_year_Currentmonth_start AND current_year_end )AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Secondary in Cases LM' [identifier], 
                     SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE WHEN SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                  (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                     THEN NULL
                     ELSE 
                         (SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, 
                                  (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                          / SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, 
                                    (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)))
                     END, 0
                     ) [achievementPercent]
             FROM TRNMAIN main
             JOIN TRNPROD prod ON main.VCHRNO = prod.vchrno
             JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
             JOIN FN_UserHierarchy_Gorkha (@TYPE, @ID) hierarchy ON com.CompanyID = hierarchy.CompanyID
             CROSS APPLY (
                         SELECT current_month_start, current_month_end, 
                                 last_month_start, last_month_end FROM #DATE
                          ) date
             LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
             WHERE (main.TRNDATE BETWEEN last_month_start AND last_month_end OR main.TRNDATE BETWEEN current_month_start AND current_month_end)AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
             UNION ALL
     
             SELECT 'Secondary in Cases LY' [identifier],
                     SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [currents],
                     SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [old],
                     ISNULL(CASE 
                             WHEN SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                          (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) = 0 
                             THEN NULL
                             ELSE 
                                 (SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, 
                                          (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) * 100.0
                                  / SUM(IIF(main.TRNDATE BETWEEN last_year_Currentmonth_start AND last_year_currentmonth_end, 
                                            (prod.REALQTY - prod.REALQTY_IN)/ ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)))
                         END ,0
                         ) [achievementPercent]
            FROM TRNMAIN main
            JOIN TRNPROD prod ON main.VCHRNO = prod.vchrno
            JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
            JOIN FN_UserHierarchy_Gorkha (@TYPE, @ID) hierarchy ON com.CompanyID = hierarchy.CompanyID
            CROSS APPLY ( 
                        SELECT current_year_start, current_year_end, 
                               last_year_Currentmonth_start, last_year_currentmonth_end 
                        FROM #DATE
                        ) date
            LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
            WHERE (main.TRNDATE BETWEEN last_year_Currentmonth_start AND current_year_end )AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
     
     )a
END
