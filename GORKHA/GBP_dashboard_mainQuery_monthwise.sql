CREATE OR ALTER     PROCEDURE [dbo].[GBP_dashboard_mainQuery_monthwise]
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
    @bs_year INT,
    @bs_month INT,
    @year INT

SELECT @bs_year = SAL , @bs_month =MAHINA from DATEMITI_FULL where AD = @ad_date

IF @bs_month < = 8
    SET @year = @bs_year -1
ELSE 
    SET @year = @bs_year

------------------------------
--DATE CALCULATION (AD => BS )
------------------------------
DROP TABLE IF EXISTS #DATE

SELECT MIN(CASE WHEN MAHINA = '09' AND SAL = @year THEN AD END) AS poush_start,
       MAX(CASE WHEN MAHINA = '09' AND SAL = @year THEN AD END) AS poush_end,
       MIN(CASE WHEN MAHINA = '10' AND SAL = @year THEN AD END) AS magh_start,
       MAX(CASE WHEN MAHINA = '10' AND SAL = @year THEN AD END) AS magh_end,
       MIN(CASE WHEN MAHINA = '11' AND SAL = @year THEN AD END) AS falgun_start,
       MAX(CASE WHEN MAHINA = '11' AND SAL = @year THEN AD END) AS falgun_end,
       MIN(CASE WHEN MAHINA = '12' AND SAL = @year THEN AD END) AS chaitra_start,
       MAX(CASE WHEN MAHINA = '12' AND SAL = @year THEN AD END) AS chaitra_end,
       MIN(CASE WHEN MAHINA = '01' AND SAL = @year + 1 THEN AD END) AS baishak_start,
       MAX(CASE WHEN MAHINA = '01' AND SAL = @year + 1 THEN AD END) AS baishak_end,
       MIN(CASE WHEN MAHINA = '02' AND SAL = @year + 1 THEN AD END) AS jestha_start,
       MAX(CASE WHEN MAHINA = '02' AND SAL = @year + 1 THEN AD END) AS jestha_end,
       MIN(CASE WHEN MAHINA = '03' AND SAL = @year + 1 THEN AD END) AS ashad_start,
       MAX(CASE WHEN MAHINA = '03' AND SAL = @year + 1 THEN AD END) AS ashad_end,
       MIN(CASE WHEN MAHINA = '04' AND SAL = @year + 1 THEN AD END) AS shrawan_start,
       MAX(CASE WHEN MAHINA = '04' AND SAL = @year + 1 THEN AD END) AS shrawan_end,
       MIN(CASE WHEN MAHINA = '05' AND SAL = @year + 1 THEN AD END) AS bhadra_start,
       MAX(CASE WHEN MAHINA = '05' AND SAL = @year + 1 THEN AD END) AS bhadra_end,
       MIN(CASE WHEN MAHINA = '06' AND SAL = @year + 1 THEN AD END) AS asoj_start,
       MAX(CASE WHEN MAHINA = '06' AND SAL = @year + 1 THEN AD END) AS asoj_end,
       MIN(CASE WHEN MAHINA = '07' AND SAL = @year + 1 THEN AD END) AS kartik_start,
       MAX(CASE WHEN MAHINA = '07' AND SAL = @year + 1 THEN AD END) AS kartik_end,
       MIN(CASE WHEN MAHINA = '08' AND SAL = @year + 1 THEN AD END) AS mangsir_start,
       MAX(CASE WHEN MAHINA = '08' AND SAL = @year + 1 THEN AD END) AS mangsir_end
INTO #DATE
FROM DATEMITI_FULL

drop table if exists #hierarchy
select companyid
into #hierarchy
from FN_UserHierarchy_Gorkha (@TYPE, @ID)

drop table if exists #mainData
CREATE TABLE #mainData ( TRNDATE date,VCHRNO VARCHAR(30)
)

IF (@ID in ('%','Admin'))
BEGIN
    INSERT INTO #mainData
    select main.TRNDATE ,   main.VCHRNO
    from RMD_TRNMAIN main
    join COMPANY com on main.COMPANYID = com.COMPANYID
    where VoucherType in ('ti','cn','pi','dn')
    and TRNDATE between (select poush_start from #DATE) and (select     mangsir_end from #DATE)
    and (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'
END

ELSE

BEGIN 
Insert Into #mainData
    select main.TRNDATE ,   main.VCHRNO
    from RMD_TRNMAIN main
    join COMPANY com on main.COMPANYID = com.COMPANYID
    join #hierarchy hie on main.companyid = hie.companyid
    where VoucherType in ('ti','cn','pi','dn')
    and TRNDATE between (select poush_start from #DATE) and (select mangsir_end from #DATE)
    and (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR  com.ADDRESS2 = @REGION) and main.PCL = 'PC007'

END

---------------
--TABLE
---------------

drop table if exists #PurchaseData
SELECT main.TRNDATE,
           sum(prod.REALQTY_IN - prod.REALQTY) AS Qty,
           prod.MCODE, 
           detail.IMPSELLINGPRICEWITHVAT,
           ISNULL(NULLIF(mau.CONFACTOR, 0), 1) AS CONFACTOR
    INTO #PurchaseData
    FROM #mainData main
    JOIN PURPROD prod ON main.VCHRNO = prod.VCHRNO
    LEFT JOIN MULTIALTUNIT mau ON prod.MCODE = mau.MCODE AND mau.ALTUNIT = 'case'
    LEFT JOIN BATCHPRICE_MASTER bp ON prod.MCODE = bp.MCODE AND prod.BATCH = bp.BATCHCODE
    LEFT JOIN DetailPrice detail ON bp.PRICEID = detail.PRICEID
    group by main.trndate , prod.mcode , detail.IMPSELLINGPRICEWITHVAT , ISNULL(NULLIF(mau.CONFACTOR, 0), 1)
    

drop table if exists #SalesData
SELECT main.TRNDATE,
           sum(prod.REALQTY - prod.REALQTY_IN) AS Qty,
           prod.MCODE, 
           detail.IMPSELLINGPRICEWITHVAT,
           ISNULL(NULLIF(mau.CONFACTOR, 0), 1) AS CONFACTOR
INTO #SalesData
FROM #mainData main
JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
LEFT JOIN MULTIALTUNIT mau ON prod.MCODE = mau.MCODE AND mau.ALTUNIT = 'case'
LEFT JOIN BATCHPRICE_MASTER bp ON prod.MCODE = bp.MCODE AND prod.BATCH = bp.BATCHCODE
LEFT JOIN DetailPrice detail ON bp.PRICEID = detail.PRICEID
group by main.trndate , prod.mcode , detail.IMPSELLINGPRICEWITHVAT , ISNULL(NULLIF(mau.CONFACTOR, 0), 1)


-----------------------
--RESULT
------------------------

SELECT Items, CAST([Poush] as numeric(32,0)) [Poush], CAST([Magh]as numeric(32,0)) [Magh], CAST([Falgun] as numeric(32,0)) [Falgun], CAST([Chaitra] as numeric(32,0)) [Chaitra], CAST([Baishak] as numeric(32,0)) [Baishak], CAST([Jestha] as numeric(32,0)) [Jestha], CAST([Ashad] as numeric(32,0)) [Ashad], CAST([Shrawan] as numeric(32,0)) [Shrawan], CAST([Bhadra] as numeric(32,0)) [Bhadra], CAST([Asoj] as numeric(32,0)) [Asoj] ,CAST([Kartik] as numeric(32,0)) [Kartik] , CAST([Mangsir] as numeric(32,0)) [Mangsir]
FROM(
SELECT 'Primary' Items,                  
                SUM(IIF(main.TRNDATE BETWEEN poush_start AND poush_end, QTY / CONFACTOR,0)) [Poush],
                SUM(IIF(main.TRNDATE BETWEEN magh_start AND magh_end, QTY / CONFACTOR,0)) [Magh],
                SUM(IIF(main.TRNDATE BETWEEN falgun_start AND falgun_end, QTY / CONFACTOR,0)) [Falgun],
                SUM(IIF(main.TRNDATE BETWEEN chaitra_start AND chaitra_end, QTY / CONFACTOR,0)) [Chaitra],
                SUM(IIF(main.TRNDATE BETWEEN baishak_start AND baishak_end, QTY / CONFACTOR,0)) [Baishak],
                SUM(IIF(main.TRNDATE BETWEEN jestha_start AND jestha_end, QTY / CONFACTOR,0)) [Jestha],
                SUM(IIF(main.TRNDATE BETWEEN ashad_start AND ashad_end, QTY / CONFACTOR,0)) [Ashad],
                SUM(IIF(main.TRNDATE BETWEEN shrawan_start AND shrawan_end, QTY / CONFACTOR,0)) [Shrawan],
                SUM(IIF(main.TRNDATE BETWEEN bhadra_start AND bhadra_end, QTY / CONFACTOR,0)) [Bhadra],
                SUM(IIF(main.TRNDATE BETWEEN asoj_start AND asoj_end, QTY / CONFACTOR,0)) [Asoj],
                SUM(IIF(main.TRNDATE BETWEEN kartik_start AND kartik_end, QTY / CONFACTOR,0)) [Kartik],
                SUM(IIF(main.TRNDATE BETWEEN mangsir_start AND mangsir_end, QTY / CONFACTOR,0)) [Mangsir]
        FROM #PurchaseData main
        cross apply #DATE
        
        UNION ALL
        
        SELECT 'Secondary' Items,
                SUM(IIF(main.TRNDATE BETWEEN poush_start AND poush_end, QTY / CONFACTOR,0)) [Poush],
                SUM(IIF(main.TRNDATE BETWEEN magh_start AND magh_end, QTY / CONFACTOR,0)) [Magh],
                SUM(IIF(main.TRNDATE BETWEEN falgun_start AND falgun_end, QTY / CONFACTOR,0)) [Falgun],
                SUM(IIF(main.TRNDATE BETWEEN chaitra_start AND chaitra_end, QTY / CONFACTOR,0)) [Chaitra],
                SUM(IIF(main.TRNDATE BETWEEN baishak_start AND baishak_end, QTY / CONFACTOR,0)) [Baishak],
                SUM(IIF(main.TRNDATE BETWEEN jestha_start AND jestha_end, QTY / CONFACTOR,0)) [Jestha],
                SUM(IIF(main.TRNDATE BETWEEN ashad_start AND ashad_end, QTY / CONFACTOR,0)) [Ashad],
                SUM(IIF(main.TRNDATE BETWEEN shrawan_start AND shrawan_end, QTY / CONFACTOR,0)) [Shrawan],
                SUM(IIF(main.TRNDATE BETWEEN bhadra_start AND bhadra_end, QTY / CONFACTOR,0)) [Bhadra],
                SUM(IIF(main.TRNDATE BETWEEN asoj_start AND asoj_end, QTY / CONFACTOR,0)) [Asoj],
                SUM(IIF(main.TRNDATE BETWEEN kartik_start AND kartik_end, QTY / CONFACTOR,0)) [Kartik],
                SUM(IIF(main.TRNDATE BETWEEN mangsir_start AND mangsir_end, QTY / CONFACTOR,0)) [Mangsir]
        FROM #SalesData main 
        cross apply #DATE
        
        UNION ALL
        
        SELECT 'Primary Value' Items,
                SUM(IIF(main.TRNDATE BETWEEN poush_start AND poush_end, QTY / CONFACTOR,0) *  IMPSELLINGPRICEWITHVAT)  [Poush],
                SUM(IIF(main.TRNDATE BETWEEN magh_start AND magh_end, QTY / CONFACTOR,0) *  IMPSELLINGPRICEWITHVAT) [Magh],
                SUM(IIF(main.TRNDATE BETWEEN falgun_start AND falgun_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Falgun],
                SUM(IIF(main.TRNDATE BETWEEN chaitra_start AND chaitra_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Chaitra],
                SUM(IIF(main.TRNDATE BETWEEN baishak_start AND baishak_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Baishak],
                SUM(IIF(main.TRNDATE BETWEEN jestha_start AND jestha_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Jestha],
                SUM(IIF(main.TRNDATE BETWEEN ashad_start AND ashad_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Ashad],
                SUM(IIF(main.TRNDATE BETWEEN shrawan_start AND shrawan_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Shrawan],
                SUM(IIF(main.TRNDATE BETWEEN bhadra_start AND bhadra_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Bhadra],
                SUM(IIF(main.TRNDATE BETWEEN asoj_start AND asoj_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Asoj],
                SUM(IIF(main.TRNDATE BETWEEN kartik_start AND kartik_end, QTY / CONFACTOR,0) *  IMPSELLINGPRICEWITHVAT) [Kartik],
                SUM(IIF(main.TRNDATE BETWEEN mangsir_start AND mangsir_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Mangsir]
        FROM #PurchaseData main 
        cross apply #DATE
        
        UNION ALL
        
        SELECT 'Secondary Value' Items,
                SUM(IIF(main.TRNDATE BETWEEN poush_start AND poush_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Poush],
                SUM(IIF(main.TRNDATE BETWEEN magh_start AND magh_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Magh],
                SUM(IIF(main.TRNDATE BETWEEN falgun_start AND falgun_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Falgun],
                SUM(IIF(main.TRNDATE BETWEEN chaitra_start AND chaitra_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Chaitra],
                SUM(IIF(main.TRNDATE BETWEEN baishak_start AND baishak_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Baishak],
                SUM(IIF(main.TRNDATE BETWEEN jestha_start AND jestha_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Jestha],
                SUM(IIF(main.TRNDATE BETWEEN ashad_start AND ashad_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Ashad],
                SUM(IIF(main.TRNDATE BETWEEN shrawan_start AND shrawan_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Shrawan],
                SUM(IIF(main.TRNDATE BETWEEN bhadra_start AND bhadra_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Bhadra],
                SUM(IIF(main.TRNDATE BETWEEN asoj_start AND asoj_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Asoj],
                SUM(IIF(main.TRNDATE BETWEEN kartik_start AND kartik_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Kartik],
                SUM(IIF(main.TRNDATE BETWEEN mangsir_start AND mangsir_end, QTY / CONFACTOR,0) * IMPSELLINGPRICEWITHVAT) [Mangsir]
       FROM #SalesData main 
       cross apply #DATE
)a
