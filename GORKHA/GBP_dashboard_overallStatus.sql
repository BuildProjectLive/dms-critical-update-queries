CREATE OR ALTER       PROCEDURE [dbo].[GBP_dashboard_overallStatus]
--DECLARE
        @DATE DATE,
        @TYPE VARCHAR(25) = '%',
        @ID VARCHAR(25) = '%',
        @DISTRIBUTOR VARCHAR(25) = '%',
        @REGION VARCHAR(100)= '%'
AS

--SELECT @DATE = '2026-01-18'
---------------------------
--PARAMETER INITIALIZATION
---------------------------

DECLARE 
    @ad_date DATE = @DATE,
    @bs_date VARCHAR(10) ,
    @bs_month INT ,
    @bs_year INT,
    @bs_day INT

SELECT @bs_date = MITI , @bs_month = MAHINA , @bs_year = SAL, @bs_day = GATE from DATEMITI_FULL where AD = @ad_date


------------------------------
--DATE CALCULATION (AD => BS )
------------------------------

DROP TABLE IF EXISTS #Date

SELECT MIN(CASE WHEN GATE = @bs_day AND MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS  current_day_start,
       MAX(CASE WHEN GATE = @bs_day AND MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_day_end,
       MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_month_start,
       MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_month_end,
      MIN(CASE 
            WHEN (MAHINA = CASE WHEN @bs_month - 2 < 1 THEN @bs_month - 2 + 12 ELSE @bs_month - 2 END
                  AND SAL    = CASE WHEN @bs_month - 2 < 1 THEN @bs_year - 1 ELSE @bs_year END)
              OR (MAHINA = CASE WHEN @bs_month - 1 < 1 THEN 12 ELSE @bs_month - 1 END
                  AND SAL    = CASE WHEN @bs_month - 1 < 1 THEN @bs_year - 1 ELSE @bs_year END)
              OR (MAHINA = @bs_month AND SAL = @bs_year)
            THEN AD 
        END) as last_3_months_start,
       MAX(CASE 
            WHEN (MAHINA = CASE WHEN @bs_month - 2 < 1 THEN @bs_month - 2 + 12 ELSE @bs_month - 2 END
                  AND SAL    = CASE WHEN @bs_month - 2 < 1 THEN @bs_year - 1 ELSE @bs_year END)
              OR (MAHINA = CASE WHEN @bs_month - 1 < 1 THEN 12 ELSE @bs_month - 1 END
                  AND SAL    = CASE WHEN @bs_month - 1 < 1 THEN @bs_year - 1 ELSE @bs_year END)
              OR (MAHINA = @bs_month AND SAL = @bs_year)
            THEN AD 
        END) as last_3_months_end
INTO #Date
FROM DATEMITI_FULL

drop table if exists #hierarchy
select companyid
into #hierarchy
from FN_UserHierarchy_Gorkha (@TYPE, @ID)


drop table if exists #main
CREATE TABLE #main 
(Trndate DATE,MCODE VARCHAR(20), VCHRNO VARCHAR(30), Qty NUMERIC(32,12), CONFACTOR NUMERIC(32,12), current_month_start date, current_month_end date,current_day_start date, current_day_end date,last_3_months_start date, last_3_months_end date, TRNAC VARCHAR(10), PARAC VARCHAR(10))

IF (@ID in ('%','Admin'))
BEGIN

INSERT INTO #main 
SELECT main.TRNDATE,prod.mcode, main.VCHRNO,(prod.REALQTY - prod.REALQTY_IN) Qty, ISNULL(NULLIF(mau.CONFACTOR, 0), 1) confactor,current_month_start, current_month_end,current_day_start, current_day_end,last_3_months_start, last_3_months_end, main.TRNAC, main.PARAC
FROM TRNMAIN main
JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
CROSS APPLY #DATE date
LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
WHERE main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'

END

ELSE
BEGIN 
INSERT INTO #MAIN
    SELECT main.TRNDATE, prod.mcode, main.VCHRNO,(prod.REALQTY - prod.REALQTY_IN) Qty, ISNULL(NULLIF(mau.CONFACTOR, 0), 1) confactor,current_month_start, current_month_end,current_day_start, current_day_end,last_3_months_start, last_3_months_end, main.TRNAC, main.PARAC
FROM TRNMAIN main
JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
JOIN #hierarchy hierarchy ON com.CompanyID = hierarchy.CompanyID
CROSS APPLY #DATE date
LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
WHERE main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
END

SELECT [Items] [Items],CAST([DAY] as numeric(32,0)) [DAY], CAST([MONTH] as numeric(32,0)) [MONTH], CAST([QTD] as numeric(32,0)) [QTD]
FROM(
SELECT 'Bill No.' [Items],
        COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, main.VCHRNO, NULL)) [DAY],
        COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end,main.VCHRNO, NULL))[MONTH],
        COUNT(DISTINCT IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, main.VCHRNO , NULL)) [QTD]
        FROM #MAIN main

UNION ALL

       SELECT 'SKU No.' [Items],
       COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end,main.MCODE,NULL)) [DAY],
       COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end ,main.MCODE,NULL)) [MONTH],
       COUNT(DISTINCT IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, main.MCODE,NULL)) [QTD]
       FROM #MAIN main

UNION ALL 

       SELECT 'Quantity(Case)' [Items],
          SUM(IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, QTY / CONFACTOR,0)) [DAY],
           SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end,QTY / CONFACTOR,0))[MONTH],
           SUM(IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, QTY /CONFACTOR,0))[QTD]
        FROM #MAIN main

UNION ALL

        SELECT 'WS no(Unique Party)' [Items],
          COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, acid.ACID,NULL)) [DAY],
          COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, acid.ACID,NULL))[MONTH],
          COUNT(DISTINCT IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, acid.ACID,NULL)) [QTD]
        FROM #MAIN main
        JOIN RMD_ACLIST acid ON COALESCE(main.TRNAC, main.PARAC) = acid.ACID
        JOIN organization_type_master org ON acid.GEO = org.OrgTypeCode
        WHERE org.OrgTypeCode = '123456-4'

UNION ALL

        SELECT 'Retail no(Unique)' [Items],
         COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, acid.ACID,NULL)) [DAY],
         COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, acid.ACID,NULL))[MONTH],
         COUNT(DISTINCT IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, acid.ACID,NULL)) [QTD]
        FROM #main main
        JOIN RMD_ACLIST acid ON COALESCE(main.TRNAC, main.PARAC) = acid.ACID
        JOIN organization_type_master org ON acid.GEO = org.OrgTypeCode
        WHERE org.OrgTypeCode = '111111-1'

UNION ALL

        SELECT 'WS qty(Case)' [Items],
           SUM(IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, QTY / CONFACTOR,0)) [DAY],
            SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, QTY / CONFACTOR,0)) [MONTH],
            SUM(IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, QTY / CONFACTOR,0)) [QTD]
            FROM #main main
            JOIN RMD_ACLIST acid ON COALESCE(main.TRNAC, main.PARAC) = acid.ACID
            JOIN organization_type_master org ON acid.GEO = org.OrgTypeCode
            WHERE org.OrgTypeCode = '123456-4'

UNION ALL

  SELECT 'WS qty(Case)' [Items],
           SUM(IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, QTY / CONFACTOR,0)) [DAY],
            SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, QTY / CONFACTOR,0)) [MONTH],
            SUM(IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, QTY / CONFACTOR,0)) [QTD]
            FROM #main main
            JOIN RMD_ACLIST acid ON COALESCE(main.TRNAC, main.PARAC) = acid.ACID
            JOIN organization_type_master org ON acid.GEO = org.OrgTypeCode
            WHERE org.OrgTypeCode = '111111-1'
)a

