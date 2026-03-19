CREATE OR ALTER   PROCEDURE [dbo].[GBP_dashboard_claimSales]
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
    @bs_year INT,
    @bs_day INT

SELECT @bs_date = MITI , @bs_month = MAHINA , @bs_year = SAL, @bs_day = GATE from DATEMITI_FULL where AD = @ad_date


------------------------------
--DATE CALCULATION (AD => BS )
------------------------------

DROP TABLE IF EXISTS #Date

SELECT MIN(CASE WHEN GATE = @bs_day AND MAHINA = @bs_month AND SAL = @bs_year THEN AD END) AS current_day_start,
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


drop table if exists #mainData
create table #mainData
    (trndate date , vchrno varchar(30) , vouchertype varchar(5) , claimtype varchar(25) , ct varchar(10) , current_day_start date , current_day_end date , current_month_start date , current_month_end date , last_3_months_start date , last_3_months_end date)

IF (@ID in ('%','Admin'))
BEGIN

    insert into #mainData
        select main.trndate , main.vchrno , main.vouchertype , isnull(typ.TypeCode , 'Normal Bills') claimType , isnull(typ.TypeCode , 'aaaaaaa') ct , current_day_start , current_day_end , current_month_start , current_month_end , last_3_months_start , last_3_months_end
        FROM TRNMAIN main
        join company com on main.companyid = com.companyid
        left join rmd_trnmain_additionalinfo info on main.vchrno = info.vchrno
        left join Type_Master typ on info.gorkha_type = typ.TypeCode
        cross apply #date dt
        where main.trndate between dt.last_3_months_start and dt.last_3_months_end
        and (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.pcl = 'PC007'

END
ELSE
BEGIN

    insert into #mainData
        select main.trndate , main.vchrno , main.vouchertype , isnull(typ.TypeCode , 'Normal Bills') claimType , isnull(typ.TypeCode , 'aaaaaaa') ct , current_day_start , current_day_end , current_month_start , current_month_end , last_3_months_start , last_3_months_end
        FROM TRNMAIN main
        join company com on main.companyid = com.companyid
        join #hierarchy hie on main.companyid = hie.companyid
        left join rmd_trnmain_additionalinfo info on main.vchrno = info.vchrno
        left join Type_Master typ on info.gorkha_type = typ.TypeCode
        cross apply #date dt
        where main.trndate between dt.last_3_months_start and dt.last_3_months_end
        and (@DISTRIBUTOR = '%' OR com.COMPANYID = @DISTRIBUTOR) AND (@REGION = '%' OR com.ADDRESS2 = @REGION) and main.PCL = 'PC007'

END

------------------------------
--AGGREGRATION OF CLAIM SALES
------------------------------

DROP TABLE IF EXISTS #CLAIM 

CREATE TABLE #CLAIM (GORKHA_TYPE varchar(25) , ct varchar(10), Bill_day INT, Bill_month INT, Bill_Year INT,Case_day NUMERIC (32,12),Case_month NUMERIC (32,12), case_year NUMERIC (32,12),totalAmount_day NUMERIC (32,12),totalAmount_month NUMERIC (32,12), totalAmount_year NUMERIC (32,12))

INSERT INTO #CLAIM
    SELECT claimType [GORKHA_TYPE], ct ,
            COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end and main.vouchertype = 'TI', main.VCHRNO, NULL)) [bill_day],
            COUNT(DISTINCT IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end and main.vouchertype = 'TI', main.VCHRNO ,NULL)) [bill_month],
            COUNT(DISTINCT IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end and main.vouchertype = 'TI', main.VCHRNO ,NULL)) [bill_Year],
            SUM(IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [case_day],
            SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [case_month],
            SUM(IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0)) [case_year],
             SUM(IIF(main.TRNDATE BETWEEN current_day_start AND current_day_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0) * IIF(ISNULL(MAU.CONFACTOR,0) = 0 , detail.COMPLEMENTARYRATE , detail.COMPLEMENTARYRATE / MAU.CONFACTOR) ) [totalAmount_day],
            SUM(IIF(main.TRNDATE BETWEEN current_month_start AND current_month_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0) * IIF(ISNULL(MAU.CONFACTOR,0) = 0 , detail.COMPLEMENTARYRATE , detail.COMPLEMENTARYRATE / MAU.CONFACTOR)) [totalAmount_month],
            SUM(IIF(main.TRNDATE BETWEEN last_3_months_start AND last_3_months_end, (prod.REALQTY - prod.REALQTY_IN) / ISNULL(NULLIF(mau.CONFACTOR, 0), 1),0) * IIF(ISNULL(MAU.CONFACTOR,0) = 0 , detail.COMPLEMENTARYRATE , detail.COMPLEMENTARYRATE / MAU.CONFACTOR)) [totalAmount_year]
    FROM #mainData main
    JOIN TRNPROD prod ON main.VCHRNO = prod.VCHRNO
    JOIN BATCHPRICE_MASTER Batchprice ON prod.MCODE = Batchprice.MCODE AND prod.BATCH = Batchprice.BATCHCODE
    JOIN DetailPrice detail ON Batchprice.PRICEID = detail.PRICEID AND Batchprice.MCODE= detail.MCODE
    LEFT JOIN MULTIALTUNIT mau ON prod.mcode = mau.mcode AND mau.ALTUNIT = 'case'
    GROUP BY claimType , ct


------------
--RESULT
------------

SELECT GORKHA_TYPE [Category], bill_day [BillCut_Day], bill_month [BillCut_Month], bill_year [BillCut_QTD],cast(case_day as numeric(32,0)) [Cases_Day],cast(case_month as numeric(32,0)) [Cases_Month], cast(case_year as numeric(32,0)) [Cases_QTD], cast(totalAmount_day as numeric(32,0)) [TotalAmount_Day],cast(totalAmount_month as numeric(32,0)) [TotalAmount_Month], cast(totalAmount_year as numeric(32,0)) [TotalAmount_QTD]
FROM (

    SELECT GORKHA_TYPE, Bill_day, Bill_month, Bill_Year,Case_day,Case_month, case_year ,totalAmount_day ,totalAmount_month , totalAmount_year, 'A' flg , ct FROM #CLAIM

    UNION ALL

    SELECT 'TOTAL', SUM(Bill_day) Bill_day, SUM(Bill_month) Bill_month, SUM(Bill_Year) Bill_Year, SUM(Case_day) Case_day, SUM(Case_month)Case_month,SUM(case_year) case_year ,SUM(totalAmount_day) totalAmount_day ,SUM(totalAmount_month ) totalAmount_month, SUM(totalAmount_year) totalAmount_year, 'Z' flg , null ct
    FROM #CLAIM
)a
ORDER BY flg , ct;



