CREATE OR ALTER     PROCEDURE [dbo].[GBP_dashboard_brandWiseAchievement]
--DECLARE
        @DATE DATE,
        @TYPE VARCHAR(25) = '%',
        @ID VARCHAR(25) = '%',
        @DISTRIBUTOR VARCHAR(25) = '%',
        @REGION VARCHAR(100) = '%'
AS

--SELECT @DATE = GETDATE(), @TYPE = '%'

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
    MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_month_start,
    MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END)AS last_month_end,
    MIN(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_start,
    MAX(CASE WHEN SAL = @bs_year THEN AD END) AS current_year_end,
    MIN(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_Currentmonth_start,
    MAX(CASE WHEN MAHINA = @bs_month AND SAL = @bs_year - 1 THEN AD END) AS last_year_currentmonth_end,
    MIN(CASE WHEN SAL = @bs_year - 1 THEN AD END) AS last_year_start,
    MAX(CASE WHEN SAL = @bs_year - 1 THEN AD END) AS last_year_end
INTO #Date
FROM DATEMITI_FULL;


drop table if exists #hierarchy
select companyid
into #hierarchy
from FN_UserHierarchy_Gorkha (@TYPE, @ID)

---------------------------------------------
--AGGREGRATION OF BRANDWISE ACHIEVEMENT IN %
---------------------------------------------

DROP TABLE IF EXISTS #PERCENTS 

CREATE TABLE #PERCENTS (Segment VARCHAR(50), MTD DECIMAL(10, 2), LY_MTD DECIMAL(10, 2), YTD DECIMAL(10, 2),LY_YTD DECIMAL(10, 2))

IF (@ID in ('%','Admin'))
BEGIN

    INSERT INTO #PERCENTS
    SELECT brand.Segment,
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.current_month_start AND date.current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.current_month_start AND date.current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER   (), 0
        ) [MTD],
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.last_month_start AND date.last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.last_month_start AND date.last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER (), 0
        ) [LY_MTD],
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.current_year_start AND date.current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.current_year_start AND date.current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER     (), 0
        ) [YTD],
        ISNULL(100.0 * SUM(IIF(main.TRNDATE BETWEEN date.last_year_start AND date.last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.last_year_start AND date.last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER (), 0
        ) ,0) [LY_YTD]
    FROM TRNMAIN main
    JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
    JOIN MENUITEM menuitem ON prod.MCODE = menuitem.MCODE
    --JOIN Brand brand ON brand.BRANDCODE = menuitem.BRANDCODE AND brand.TYPE = 'VERTICAL'
    JOIN    (
            SELECT B.BRANDNAME , B.BRANDCODE , A.BRANDNAME Segment FROM BRAND A
            INNER JOIN BRAND B ON A.BRANDID = B.PARENTBRANDCODE
            WHERE A.TYPE = 'VERTICAL'
            ) brand ON brand.BRANDCODE = menuitem.BRANDCODE
    JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
    CROSS APPLY (
                SELECT current_month_start, current_month_end,
                        last_month_start, last_month_end,
                        current_year_start, current_year_end,
                        last_year_start,last_year_end
                FROM #DATE
                ) date
    LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
    WHERE main.TRNDATE between last_year_start and current_year_end
    AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
    GROUP BY brand.Segment

END

ELSE
BEGIN

    INSERT INTO #PERCENTS
    SELECT brand.brandName [Segment],
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.current_month_start AND date.current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.current_month_start AND date.current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER   (), 0
        ) [MTD],
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.last_month_start AND date.last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.last_month_start AND date.last_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER (), 0
        ) [LY_MTD],
        100.0 * SUM(IIF(main.TRNDATE BETWEEN date.current_year_start AND date.current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.current_year_start AND date.current_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER     (), 0
        ) [YTD],
        ISNULL(100.0 * SUM(IIF(main.TRNDATE BETWEEN date.last_year_start AND date.last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0))
        / NULLIF( SUM( SUM(IIF(main.TRNDATE BETWEEN date.last_year_start AND date.last_year_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1), 0)) ) OVER (), 0
        ) ,0) [LY_YTD]
    FROM TRNMAIN main
    JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
    JOIN MENUITEM menuitem ON prod.MCODE = menuitem.MCODE
    JOIN    (
        SELECT B.BRANDNAME , B.BRANDCODE , A.BRANDNAME Segment FROM BRAND A
        INNER JOIN BRAND B ON A.BRANDID = B.PARENTBRANDCODE
        WHERE A.TYPE = 'VERTICAL'
        ) brand ON brand.BRANDCODE = menuitem.BRANDCODE
    JOIN COMPANY Com ON main.COMPANYID = com.COMPANYID
    JOIN #hierarchy hierarchy ON com.CompanyID = hierarchy.CompanyID
    CROSS APPLY (
                SELECT current_month_start, current_month_end,
                        last_month_start, last_month_end,
                        current_year_start, current_year_end,
                        last_year_start,last_year_end
                FROM #DATE
                ) date
    LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
    WHERE  main.TRNDATE between last_year_start and current_year_end
    AND (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
    GROUP BY brand.brandName

END


----------
--RESULT
----------

SELECT [Segment], [MTD], [LY_MTD], [YTD], [LY_YTD]
FROM (
    SELECT [Segment], ISNULL([MTD],0) [MTD], ISNULL([LY_MTD],0)[LY_MTD], ISNULL([YTD],0) [YTD],ISNULL([LY_YTD] ,0) [LY_YTD], 'A'[flg] 
    FROM #PERCENTS
    
    UNION ALL
    
    SELECT DISTINCT 'Total' [Segment],100 [MTD],100 [LY_MTD], 100 [YTD], 100 [LY_YTD], 'Z' [flg] 
    FROM #PERCENTS
)a
ORDER BY flg;


