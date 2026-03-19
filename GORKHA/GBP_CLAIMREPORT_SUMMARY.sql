CREATE OR ALTER             PROCEDURE [dbo].[GBP_CLAIMREPORT_SUMMARY]
--DECLARE
	@DATE1 DATE = NULL,
	@DATE2 DATE = NULL,
	@COMPANYID VARCHAR(255) = '%',
	@ACID VARCHAR(100) = '%',
	@CLAIMTYPE TINYINT = 1				-- 0 : Sales Claim || 1: Brand Calim || 2 : Admin Claim  || 3 : Tie-Up Calim
	,@REPCRITERIA VARCHAR(MAX) OUTPUT,
	@REPORTNAME VARCHAR(MAX) OUTPUT

AS

/*
SELECT @DATE1 = '2025-12-01' , @DATE2 = '2026-01-30' , @COMPANYID = '%'--(select companyid from company where INITIAL = 'rea') 
, @CLAIMTYPE = 5--, @ACID = 'PAd21'
--*/

SET @REPCRITERIA = '@As On Dated : ' + FORMAT(@DATE1, 'MM-dd-yyyy')  + ' - ' + FORMAT(@DATE2, 'MM-dd-yyyy')
SET @REPORTNAME = 'Claim Report - Summary';

/*/*/*/*/*/*/*/*
select 
	STRING_AGG(CASE WHEN SNO NOT IN (6,9) THEN CAST('' AS NVARCHAR(MAX))+exTypCod END,',') WITHIN GROUP (ORDER BY SNO ASC) , 
	STRING_AGG(CAST('' AS NVARCHAR(MAX))+exTypCod+' AS '+QUOTENAME(exTypCat + ' ~ ' + exTypNam),',') WITHIN GROUP (ORDER BY SNO ASC)
from ( values
		(1,'P4P Discounts','[PP]','Sales Claim') , (2,'Outlet Promotion','[OP]','Sales Claim') , (3,'Non Channel / Events','[NEV]','Sales Claim') , (7,'Sponsorship Brand Marketing','[BC]','Brand/Admin Claim') , (8,'Admin Claim','[AC]','Brand/Admin Claim') , (4,'Tie-up Volume Based','[TVB]','Sales Claim') , (5,'Tie-up Display and Exclusive','[TEX]','Sales Claim') , (6,'Total','[PP]+[OP]+[NEV]+[TVB]+[TEX]','Sales Claim') , (9,'Total','[BC]+[AC]','Sales Claim')
	) as a (sno,exTypNam , exTypCod , exTypCat)
--*/*/*/*/*/*/*/*/


DROP TABLE IF EXISTS #COMPSALES

SELECT C.GORKHA_TYPE ExpenseTypeCode , TRIM(A.REFBILL) REFVCHR , A.VCHRNO , A.PARAC , A.TRNDATE , A.TRNTIME , B.MCODE , SUM(B.RealQty) COMPSALESQTY , SUM(AltQty) COMPSALESQTY_ALT , CONVERT(NUMERIC(32,4),IIF(ISNULL(MAU.CONFACTOR,0) = 0 , DP.COMPLEMENTARYRATE , DP.COMPLEMENTARYRATE / MAU.CONFACTOR)) COMPLEMENTARYRATE , CC.nav_name NavName , CC.nav_code NavCode , CC.Name Name, CC.companyid CompanyId, MI.MCODE ProductCode , MI.DESCA ProductName, ISNULL(CC.ADDRESS2,'') Region
INTO #COMPSALES
FROM TRNMAIN A 
JOIN TRNPROD B ON A.VCHRNO = B.VCHRNO
JOIN BATCHPRICE_MASTER BM ON B.MCODE = BM.MCODE AND B.BATCH = BM.BATCHCODE
JOIN DetailPrice DP ON BM.PRICEID = DP.PRICEID AND BM.MCODE= DP.MCODE
JOIN RMD_TRNMAIN_ADDITIONALINFO C ON A.VCHRNO = C.VCHRNO
JOIN MENUITEM MI ON B.MCODE = MI.MCODE
LEFT JOIN MULTIALTUNIT MAU WITH (NOLOCK) ON B.MCODE = MAU.MCODE AND MAU.ALTUNIT = 'CASE'
LEFT JOIN RMD_ACLIST R ON MI.Supplier = R.ACID
LEFT JOIN COMPANY CC WITH (NOLOCK) ON A.COMPANYID = CC.COMPANYID
WHERE A.TRNDATE BETWEEN @DATE1 AND @DATE2 AND A.VoucherType = 'TI' AND C.GORKHA_TYPE IN ('PP','OP','NEV','TVB','TEX','BC','AC','MKB')
AND (@COMPANYID = '%' OR A.COMPANYID IN (SELECT * FROM DBO.Split(@COMPANYID,',')))
AND (@ACID = '%' OR R.ACID IN (SELECT * FROM DBO.Split(@ACID,',')))
AND A.PCL = 'PC007'
GROUP BY C.GORKHA_TYPE , TRIM(A.REFBILL) , A.PARAC , A.VCHRNO , A.TRNDATE , A.TRNTIME , B.MCODE , IIF(ISNULL(MAU.CONFACTOR,0) = 0 , DP.COMPLEMENTARYRATE , DP.COMPLEMENTARYRATE / MAU.CONFACTOR) , CC.nav_name , CC.nav_code , MI.MCODE , MI.DESCA, CC.Name , CC.companyid,ISNULL(CC.ADDRESS2,'') 


DROP TABLE IF EXISTS #SALES

SELECT A.VCHRNO , B.MCODE , SUM(RealQty) SALESQTY ,sum(AltQty) SALESQTY_ALT , A.COMPANYID
INTO #SALES
FROM TRNMAIN A
JOIN TRNPROD B ON A.VCHRNO = B.VCHRNO
JOIN MENUITEM MI ON B.MCODE = MI.MCODE
LEFT JOIN RMD_ACLIST R ON MI.Supplier = R.ACID
WHERE A.TRNDATE BETWEEN @DATE1 AND @DATE2 AND A.VoucherType = 'TI'
AND (@COMPANYID = '%' OR A.COMPANYID IN (SELECT * FROM DBO.Split(@COMPANYID,',')))
AND (@ACID = '%' OR R.ACID IN (SELECT * FROM DBO.Split(@ACID,',')))
AND A.PCL = 'PC007'
--AND EXISTS (SELECT * FROM #COMPSALES X WHERE A.VCHRNO = X.REFVCHR)
GROUP BY A.VCHRNO , B.MCODE , A.COMPANYID


DROP TABLE IF EXISTS #SALESRETURN

SELECT TRIM(A.REFBILL) REFBILL , B.MCODE , SUM(REALQTY_IN) SALESRETURNQTY ,sum(ALTQTY_IN) SALESRETURNQTY_ALT
INTO #SALESRETURN
FROM TRNMAIN A
JOIN TRNPROD B ON A.VCHRNO = B.VCHRNO
JOIN MENUITEM MI ON B.MCODE = MI.MCODE
LEFT JOIN RMD_ACLIST R ON MI.Supplier = R.ACID
WHERE A.TRNDATE BETWEEN @DATE1 AND @DATE2 AND A.VoucherType = 'CN'
AND (@COMPANYID = '%' OR A.COMPANYID IN (SELECT * FROM DBO.Split(@COMPANYID,',')))
AND (@ACID = '%' OR R.ACID IN (SELECT * FROM DBO.Split(@ACID,',')))
AND A.PCL = 'PC007'
--AND EXISTS (SELECT * FROM #COMPSALES X WHERE TRIM(A.REFBILL) = X.VCHRNO)
GROUP BY TRIM(A.REFBILL) , B.MCODE

DROP TABLE IF EXISTS #RAWRDATA

SELECT M.MCODE ProductCode ,M.DESCA ProductName ,C.nav_name NavName,C.nav_code NavCode, C.Name, C.CompanyId,ISNULL(C.ADDRESS2 , '') Region, A.Type ,
SUM(ISNULL(CompAmount,0)) CompAmount , SUM(ISNULL(CompQty,0)) QTY , SUM(ISNULL(QtyCase,0)) ALTQTY
INTO #RAWRDATA
FROM	(
		SELECT REFVCHR , VCHRNO ,ProductCode , ProductName ,NavName, NavCode, C.Name, C.CompanyId,C.Region, ExpenseTypeCode Type ,
		IIF(ExpenseTypeCode = 'AC' , CAST((c.COMPSALESQTY - ISNULL(YY.SALESRETURNQTY,0)) * C.COMPLEMENTARYRATE AS NUMERIC(32,2)) , CAST(((c.COMPSALESQTY - ISNULL(YY.SALESRETURNQTY,0))*C.COMPLEMENTARYRATE) / 0.85 AS NUMERIC(32,2)))CompAmount ,
		(C.COMPSALESQTY - ISNULL(SALESRETURNQTY,0)) CompQty , PARAC , C.MCODE
		FROM #COMPSALES C
		LEFT JOIN #SALESRETURN YY ON C.VCHRNO = YY.REFBILL AND C.MCODE = YY.MCODE
		) A
FULL JOIN	(
			SELECT VCHRNO, A.MCODE ,ISNULL(A.SALESQTY,0) - ISNULL(C.SALESRETURNQTY,0) Qty , A.COMPANYID ,
			ISNULL(A.SALESQTY_ALT,0) - ISNULL(C.SALESRETURNQTY_ALT , 0) QtyCase
			FROM #SALES A
			LEFT JOIN #SALESRETURN C ON A.VCHRNO = C.REFBILL AND A.MCODE = C.MCODE
			) B ON A.REFVCHR = B.VCHRNO AND A.MCODE = B.MCODE
LEFT JOIN MENUITEM M ON ISNULL(A.MCODE , B.MCODE) = M.MCODE
LEFT JOIN COMPANY C ON ISNULL(A.COMPANYID , B.COMPANYID)= C.COMPANYID
GROUP BY M.MCODE  ,M.DESCA , A.Type,C.nav_name ,C.nav_code , C.Name, C.CompanyId,ISNULL(C.ADDRESS2 , '')


IF @CLAIMTYPE = 0
BEGIN

	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] , ProductName AS [ProductName],
	SUM(ISNULL([PP],0)) AS [Sales Claim ~ 3210130 (PP)] , SUM(ISNULL([NEV],0)) AS [Sales Claim ~ 3220150 (NEV)],
	SUM(ISNULL([PP],0))+SUM(ISNULL([NEV],0)) AS [Sales Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([PP],[NEV])
			) B
	GROUP BY ProductCode , ProductName,NavName, NavCode, Name,CompanyId,Region
	HAVING SUM(ISNULL([PP],0))+SUM(ISNULL([NEV],0)) <> 0


	SELECT 'Total' AS [ProductName], SUM(ISNULL([PP],0)) AS [Sales Claim ~ 3210130 (PP)],
	SUM(ISNULL([NEV],0)) AS [Sales Claim ~ 3220150 (NEV)],
	SUM(ISNULL([PP],0))+SUM(ISNULL([OP],0))+SUM(ISNULL([NEV],0)) AS [Sales Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([PP],[OP],[NEV])
			) B
	HAVING SUM(ISNULL([PP],0))+SUM(ISNULL([OP],0))+SUM(ISNULL([NEV],0)) <> 0

END
ELSE IF @CLAIMTYPE = 1
BEGIN

	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] , ProductName AS [ProductName], SUM(ISNULL([BC],0)) AS [Brand Claim ~ 6230130 (BC) ],
	SUM(ISNULL([BC],0)) AS [Brand Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([BC])
			) B
	GROUP BY ProductCode , ProductName,NavName, NavCode, Name,CompanyId,Region
	HAVING SUM(ISNULL([BC],0)) <> 0


	SELECT 
	'Total' AS [ProductName], SUM(ISNULL([BC],0)) AS [Brand Claim ~ 6230130 (BC) ] , SUM(ISNULL([BC],0)) AS [Brand Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([BC])
			) B
	HAVING SUM(ISNULL([BC],0)) <> 0


END
ELSE IF @CLAIMTYPE = 2

BEGIN

	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] , ProductName AS [ProductName], SUM(ISNULL([AC],0)) AS [Admin Claim ~ 3220150 (AC)], SUM(ISNULL([AC],0)) AS [Admin Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([AC])
			) B
	GROUP BY ProductCode , ProductName,NavName, NavCode, Name,CompanyId,Region
	HAVING SUM(ISNULL([AC],0)) <> 0


	SELECT 
	'Total' AS [ProductName] , SUM(ISNULL([AC],0)) AS [Admin Claim ~ 3220150 (AC)], SUM(ISNULL([AC],0)) AS [Admin Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([AC])
			) B
	HAVING SUM(ISNULL([AC],0)) <> 0


END
ELSE IF @CLAIMTYPE = 3
BEGIN

	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] , ProductName AS [ProductName], SUM(ISNULL([TVB],0)) AS [Tie-Up ~ 3220111 (TVB)],
	SUM(ISNULL([TEX],0)) AS [Tie-Up ~ 6115150 (TEX)], SUM(ISNULL([TVB],0))+SUM(ISNULL([TEX],0)) AS [Tie-Up ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([TVB],[TEX])
			) B
	GROUP BY ProductCode , ProductName,NavName, NavCode, Name,CompanyId,Region
	HAVING SUM(ISNULL([TVB],0))+SUM(ISNULL([TEX],0)) <> 0


	SELECT 'Total' AS [ProductName], SUM(ISNULL([TVB],0)) AS [Tie-Up ~ 3220111 (TVB)], SUM(ISNULL([TEX],0)) AS [Tie-Up ~ 6115150 (TEX)] ,
	SUM(ISNULL([TVB],0))+SUM(ISNULL([TEX],0)) AS [Tie-Up ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([TVB],[TEX])
			) B
	HAVING SUM(ISNULL([TVB],0))+SUM(ISNULL([TEX],0)) <> 0

END
ELSE  IF @CLAIMTYPE = 4
BEGIN

	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] , ProductName AS [ProductName],
	SUM(ISNULL([OP],0)) AS [Outlet Promotion Claim ~ 3220150 (OP)], SUM(ISNULL([OP],0)) AS [Outlet Promotion Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([OP])
			) B
	GROUP BY ProductCode , ProductName,NavName, NavCode, Name,CompanyId,Region
	HAVING SUM(ISNULL([OP],0)) <> 0


	SELECT 'Total' AS [ProductName], SUM(ISNULL([OP],0)) AS [Outlet Promotion Claim ~ 3220150 (OP)],
	SUM(ISNULL([OP],0)) AS [Outlet Promotion Claim ~ Total]
	FROM #RAWRDATA A
	PIVOT	(
			SUM(CompAmount) FOR Type in ([OP])
			) B
	HAVING SUM(ISNULL([OP],0)) <> 0

END

ELSE
BEGIN


	SELECT NavName, NavCode, Name [DistributorName],CompanyId [DistributorCode],Region,ProductCode AS [ProductCode] ,
	ProductName AS [ProductName], SUM(ALTQTY) [Sales (CS)] , SUM(ALTQTY * (10.00/ 1.15)) [Approved Budget @8.5] ,
	SUM(IIF(TYPE = 'MKB',ISNULL(QTY,0) ,0)) AS [Breakage Exchanged in Market (PCS)] ,
	SUM(IIF(TYPE = 'MKB' , CompAmount ,0)) AS [Breakage Exchanged in Market (Amount)], SUM(ALTQTY * 10.00) [Approved Bonous]
	FROM #RAWRDATA A
	GROUP BY ProductCode , ProductName , NavName, NavCode , Name , CompanyId , Region

	SELECT 'Total' AS [ProductName], SUM(ISNULL(ALTQTY,0)) [Sales (CS)] ,
	SUM(ALTQTY * (10.00/ 1.15)) [Approved Budget @8.5] ,
	SUM(IIF(TYPE = 'MKB',ISNULL(QTY,0) ,0)) AS [Breakage Exchanged in Market (PCS)] ,
	SUM(IIF(TYPE = 'MKB' , CompAmount ,0)) AS [Breakage Exchanged in Market (Amount)], SUM(ALTQTY * 10.00) [Approved Bonous]
	FROM #RAWRDATA A

END