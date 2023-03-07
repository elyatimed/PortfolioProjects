use Sales_Analysis

select * from sales

--Total Rows 
select count(*) as total_rows from sales

--Checking Unique Values 

select distinct Status from sales
select distinct YEAR_ID from sales
select distinct Productline from sales
select distinct TERRITORY from sales
select distinct country from sales 
select distinct DealSize from sales



-- country column contain values like 'B900','N-755' instead of country names , so we placed these values with Territory values .
update sales
set country= case 
when ISNUMERIC(country) = 0 AND country NOT LIKE '%[^a-zA-Z0-9]%' then COUNTRY
else TERRITORY 
end 

--- Now we have country names
select distinct country from sales

--- Analysis 

---- Checking sales Status (Shipped , In Process On Hold , Cancelled .... )
select Status , count(*) from sales 
group by Status

----Grouping Sales by Productline

-- first we have to change the necessary column from Varchar to float / int 

alter table sales 
alter COLUMN quantityordered int 

alter table sales
alter column month_id int

select Productline , sum(cast(sales as float)) as Revenue , sum(quantityordered) as total_quantity    from sales 
group by PRODUCTLINE
order by 2 desc

--- Revenue by year 

select YEAR_ID , sum(cast(sales as float)) as Revenue  from sales 
group by YEAR_ID
order by 2 desc

----What was the best month for sales in a specific year? How much was earned that month? 

select MONTH_ID , sum(cast(sales as float)) as revenue from sales 
where YEAR_ID='2004'
group by MONTH_ID
order by month_id ASC

-- Revenue of Each Month of every year 

select YEAR_ID , MONTH_ID , sum(cast(sales as float)) as revenue from sales 
group by Year_ID, MONTH_ID
order by year_id , month_id ASC

--November seems to be the month, what product do they sell in November ?

select productline, sum(cast(sales as float)) as revenue from sales 
where MONTH_ID=11
group by productline 
order by 2 DESC

alter table sales
alter column sales float
----Who is our best customer (this could be best answered with RFM)
DROP TABLE IF EXISTS #rfm
;with rfm as 
(
	select 
		CUSTOMERNAME, 
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from sales) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales)) Recency
	from sales
	group by CUSTOMERNAME
),
rfm_calc as
(

	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency+ rfm_frequency+ rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar)rfm_cell_string
into #rfm
from rfm_calc c

select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331 ,421, 412) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322 , 234 ,232 ,221 ) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432 , 423  ) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

--What products are most often sold together? 

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from sales p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM sales
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from sales s
order by 2 desc