CREATE OR ALTER     PROCEDURE [dbo].[GBP_TransportBreakageLeakageClaim_PRINT]
--declare
	@DATE1 DATE = NULL,
	@DATE2 DATE = NULL,
	@COMPANYID VARCHAR(255) = '%',
	@ACID VARCHAR(255) = '%'
	--,@REPCRITERIA VARCHAR(MAX) OUTPUT,
	--@REPORTNAME VARCHAR(MAX) OUTPUT

AS

--/*
--select @DATE1 = '2025-01-01' , @DATE2 = '2025-12-12'
--*/

--SET @REPORTNAME = 'Claim Report - Transport Breakage Leakage'
--SET @REPCRITERIA = '@As On Dated : ' + FORMAT(@DATE1, 'MM-dd-yyyy')  + ' - ' + FORMAT(@DATE2, 'MM-dd-yyyy')

DROP TABLE IF EXISTS #lbRawData

select e.DeliveryNote , e.PWSNo , convert(varchar,b.TRNDATE,23) InvoiceDate , f.NAME DistributorName , e.TRANSPORTER TransportName , m.DESCA [Description] , (isnull(c.REALQTY_IN,0)) InvoiceQty , c.RATE DispatchRate , (isnull(d.Leakage,0)) Leakage , (isnull(d.Breakage,0)) Breakage , (isnull(d.Shortage,0)) Shortage , (isnull(d.Carton,0)) Carton , ((isnull(d.Leakage,0) + isnull(d.Breakage,0) + isnull(d.Shortage,0) + isnull(d.Carton,0))*c.RATE) Amount , e.VEHICLENO TruckNumber , e.DRIVERNAME , e.DRIVERNO DriverNumber
INTO #lbRawData
from INVMAIN a
join PURMAIN b on a.refbill = b.vchrno
join PURPROD c on b.VCHRNO = c.VCHRNO
join LEAKAGEBREAKAGE_SUMMARY d on a.VCHRNO = d.VCHRNO and c.MCODE = d.MCODE and c.MANUFACTURER = d.MANUFACTURER
join Transporter_Eway e on a.VCHRNO = e.VCHRNO
join menuitem m on d.MCODE = m.MCODE
left join COMPANY f on b.COMPANYID = f.COMPANYID
where b.TRNDATE between @DATE1 and @DATE2
and (@COMPANYID = '%' or b.COMPANYID = @COMPANYID)
and (@ACID = '%' or m.Supplier = @ACID)


select DeliveryNote , PWSNo , InvoiceDate , DistributorName , TransportName , [Description] , FORMAT(InvoiceQty , 'N2') InvoiceQty , 
FORMAT(DispatchRate , 'N2') DispatchRate , FORMAT(Leakage , 'N2') Leakage , FORMAT(Breakage , 'N2') Breakage , FORMAT(Shortage , 'N2') Shortage ,
FORMAT(Carton , 'N2') Carton , FORMAT(Amount , 'N') Amount , TruckNumber , DRIVERNAME , DriverNumber
from #lbRawData
union all
select CHAR(10)+CHAR(13) DeliveryNote , NULL PWSNo , NULL InvoiceDate , NULL DistributorName , NULL TransportName , NULL [Description] , NULL InvoiceQty ,
NULL DispatchRate , NULL Leakage , NULL Breakage , NULL Shortage , NULL Carton , NULL Amount , NULL TruckNumber , NULL DRIVERNAME , NULL DriverNumber
UNION ALL
select  'TOTAL' DeliveryNote ,NULL PWSNo , NULL InvoiceDate ,NULL DistributorName , NULL TransportName , NULL [Description] ,
FORMAT(sum(InvoiceQty) , 'N2') InvoiceQty , NULL , FORMAT(sum(Leakage) , 'N2') Leakage ,  FORMAT(sum(Breakage) , 'N2') Breakage ,
FORMAT(sum(Shortage) , 'N2') Shortage , FORMAT(sum(Carton) , 'N2') Carton , FORMAT(sum(Amount) , 'N2') Amount , NULL TruckNumber , NULL DRIVERNAME ,
 NULL DriverNumber
from #lbRawData 
