CREATE OR ALTER     PROCEDURE [dbo].[GBP_dashboard_topTenSKU]
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
       MIN(CASE WHEN MAHINA = CASE WHEN @bs_month-1 < 1 THEN 12 ELSE @bs_month - 1 END AND SAL = CASE WHEN @bs_month-1 < 1 THEN @bs_year - 1 ELSE @bs_year-1 END THEN AD END) AS last_month_start,
       MAX(CASE WHEN MAHINA = CASE WHEN @bs_month -1< 1 THEN 12 ELSE @bs_month - 1 END AND SAL = CASE WHEN @bs_month -1< 1 THEN @bs_year - 1 ELSE @bs_year-1 END THEN AD END) AS last_month_end,
       MIN(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_start,
       MAX(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_end,
       MIN(CASE WHEN SAL = @bs_year - 1 THEN AD END) AS last_year_start,
       MAX(CASE WHEN SAL = @bs_year - 1 THEN AD END) AS last_year_end,
       MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_current_month_start,
       MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_current_month_end
INTO #Date
FROM DATEMITI_FULL;


--------------------------------
--AGGREGRATION OF TOP TEN ITEMS
--------------------------------

DROP TABLE IF EXISTS #TOPITEM
CREATE TABLE #TOPITEM (SKU varchar(150), MTD NUMERIC (32,12), LY_MTD NUMERIC (32,12), YTD NUMERIC (32,12),LY_YTD NUMERIC (32,12))

IF (@ID in ('%','Admin'))
BEGIN

    INSERT INTO #TOPITEM
    SELECT menuitem.DESCA [SKU],
        SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [MTD],
        SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [LY_MTD],
        SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [YTD],
        SUM(IIF(main.TRNDATE BETWEEN last_year_start AND last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [LY_YTD]
    FROM TRNMAIN main
    JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
    JOIN MENUITEM menuitem ON prod.MCODE = menuitem.MCODE
    JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
    CROSS APPLY (
                 SELECT current_month_start, current_month_end, 
                        last_month_start, last_month_end,
                        current_year_start, current_year_end, 
                        last_year_start, last_year_end, 
                        last_year_current_month_start, last_year_current_month_end
                 FROM #DATE
                ) date
    LEFT JOIN MULTIALTUNIT mau ON menuitem.mcode = mau.mcode AND mau.ALTUNIT = 'case'
    WHERE main.TRNDATE BETWEEN last_year_start AND current_year_end AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
    GROUP BY menuitem.DESCA
    ORDER BY SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) DESC;

END

ELSE
BEGIN

    INSERT INTO #TOPITEM
    SELECT menuitem.DESCA [SKU],
        SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [MTD],
        SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [LY_MTD],
        SUM(IIF(main.TRNDATE BETWEEN current_year_start AND current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [YTD],
        SUM(IIF(main.TRNDATE BETWEEN last_year_start AND last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [LY_YTD]
    FROM TRNMAIN main
    JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
    JOIN MENUITEM menuitem ON prod.MCODE = menuitem.MCODE
    JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
    JOIN FN_UserHierarchy_Gorkha (@TYPE, @ID) hierarchy ON com.CompanyID = hierarchy.CompanyID
    CROSS APPLY (
                 SELECT current_month_start, current_month_end, 
                        last_month_start, last_month_end,
                        current_year_start, current_year_end, 
                        last_year_start, last_year_end, 
                        last_year_current_month_start, last_year_current_month_end
                 FROM #DATE
                ) date
    LEFT JOIN MULTIALTUNIT mau ON menuitem.mcode = mau.mcode AND mau.ALTUNIT = 'case'
    WHERE main.TRNDATE BETWEEN last_year_start AND current_year_end AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
    GROUP BY menuitem.DESCA
    ORDER BY SUM(IIF(main.TRNDATE BETWEEN last_month_start AND last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) DESC;

END


------------
--RESULT
------------
SELECT TOP 10 [SKU] , CAST ([MTD] AS NUMERIC (32,0)) [MTD],CAST( [LY_MTD] AS NUMERIC (32,0)) [LY_MTD], CAST([YTD] AS NUMERIC (32,0))[YTD], CAST([LY_YTD] AS NUMERIC (32,0)) [LY_YTD] FROM #TOPITEM
ORDER BY [YTD] Desc;

