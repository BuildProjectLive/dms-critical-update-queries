CREATE OR ALTER PROCEDURE [dbo].[GBP_outletMasterReport_detail]
--declare 
	@DATE1 DATE,
	@DATE2 DATE,
	@COMPANYID VARCHAR(MAX) = '%'
	,@REPCRITERIA VARCHAR(MAX) OUTPUT,
	@REPORTNAME VARCHAR(MAX) OUTPUT

AS

--select @date1 = '2026-01-01' , @DATE2 = '2026-01-28'

SET @REPORTNAME = 'Outlet Master Report - Detail'
SET @REPCRITERIA = 'Date Range From : '+FORMAT(@DATE1,'MM-dd-yyyy')+' - '+FORMAT(@DATE2,'MM-dd-yyyy')


DECLARE @PCL VARCHAR(10) = 'PC007'

DROP TABLE IF EXISTS #outletMasterData
select a.ADDRESS2 region , a.nav_code navCode , a.nav_name navName , a.COMPANYID distributorCode , a.NAME distributorName , b.ACID outletAcID , b.ACNAME outletName , b.VATNO outletPAN , b.ADDRESS outletAddress , sm.StateName Province , c.OrgTypeName outletType , e.ChannelName channel , d.ChannelName subChannel , f.ChannelName Segment
into #outletMasterData
from COMPANY a
join rmd_aclist b on a.COMPANYID = b.companyid
left join ORGANIZATION_TYPE_MASTER c on b.GEO = c.OrgTypeCode
left join CHANNEL_HIERARCHY_MASTER d on b.SUBCHANNEL = d.ChannelCode and d.ChannelType = 'Sub-Channel'
left join CHANNEL_HIERARCHY_MASTER e on b.Channel = e.ChannelCode and e.ChannelType = 'Channel'
left join CHANNEL_HIERARCHY_MASTER f on b.SEGMENTTYPE = f.ChannelCode and f.ChannelType = 'Segment'
left join STATE_MASTER sm on b.STATE = sm.StateCode
where b.ACID like 'pa%' and (b.PType = 'c' or COMMON = 1)
and ((@COMPANYID = '%' and a.COMPANYID <> 'central') or a.COMPANYID = @COMPANYID)


DROP TABLE IF EXISTS #outletWiseSalesData
SELECT COMPANYID , PARAC , 
	SUM(IIF(VoucherType = 'CN' , (NETAMNT)*-1 , NETAMNT)) SALESAMNT , 
	SUM(QTYCASE) SALESQTYCASE , 
	COUNT(DISTINCT IIF(VoucherType = 'CN' , NULL , VCHRNO)) BILLCOUNT
into #outletWiseSalesData
FROM	(
		SELECT A.COMPANYID , A.PARAC , A.VCHRNO , A.VoucherType , IIF(ISNULL(MAU.CONFACTOR,0) = 0 , SUM(REALQTY - RealQty) , SUM(REALQTY - REALQTY_IN) / MAU.CONFACTOR) QTYCASE , SUM(NETAMOUNT) NETAMNT
		FROM TRNMAIN A WITH (NOLOCK)
		JOIN TRNPROD B WITH (NOLOCK) ON A.VCHRNO = B.VCHRNO
		LEFT JOIN MULTIALTUNIT MAU WITH (NOLOCK) ON B.MCODE = MAU.MCODE AND MAU.ALTUNIT = 'CASE'
		where ((@COMPANYID = '%' and A.COMPANYID <> 'central') or A.COMPANYID = @COMPANYID)
		and trndate between @DATE1 and @DATE2 AND A.PCL = @PCL
		GROUP BY A.COMPANYID , A.VOUCHERTYPE , MAU.CONFACTOR , A.PARAC , A.VCHRNO , B.MCODE
		) A
GROUP BY COMPANYID , PARAC


select region , distributorCode , distributorName , outletName , outletPAN , outletAddress , Province, outletType , channel , subChannel , segment , BILLCOUNT noOfBills , SALESQTYCASE totalSales
from #outletMasterData a
join #outletWiseSalesData b on a.distributorCode = b.COMPANYID and a.outletAcID = b.PARAC
ORDER BY distributorName asc , outletName asc

select '' region