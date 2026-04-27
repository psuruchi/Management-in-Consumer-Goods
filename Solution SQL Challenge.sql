-- Requests: Codebasics SQL Challenge 
-- 1.  Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 
Select 
	customer, market, region
from dim_customer
where region = "APAC" and customer = "Atliq Exclusive";


-- 2.  What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, 
-- unique_products_2020 
-- unique_products_2021 
-- percentage_chg 

WITH cte2020 AS (
		SELECT 
		count(distinct product_code) as unique_products_2020
	FROM gdb023.fact_gross_price
	where fiscal_year = 2020
    ),

cte2021 AS (
		SELECT 
		count(distinct product_code) as unique_products_2021
		FROM gdb023.fact_gross_price
		where fiscal_year = 2021
        )

select 
	c.unique_products_2020,
    e.unique_products_2021,
    ((e.unique_products_2021 - c.unique_products_2020)/c.unique_products_2020)*100 as percentage_chg
from cte2020 c
CROSS JOIN cte2021 e;


-- 3.  Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. The final output contains 2 fields, 
-- segment 
-- product_count 

SELECT 
	segment,
    count(distinct product_code) as product_count
FROM gdb023.dim_product
group by segment
order by product_count desc;


-- 4.  Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, 
-- segment 
-- product_count_2020 
-- product_count_2021 
-- difference 

with cte2020 as (
		SELECT 
			p.segment,
			count(distinct p.product_code) as product_count_2020
		FROM gdb023.dim_product p 
		JOIN gdb023.fact_sales_monthly s
			ON p.product_code = s.product_code 
		where s.fiscal_year = 2020
		group by p.segment
			),
cte2021 as (
		SELECT 
			p.segment,
			count(distinct p.product_code) as product_count_2021
		FROM gdb023.dim_product p 
		JOIN gdb023.fact_sales_monthly s
			ON p.product_code = s.product_code 
		where s.fiscal_year = 2021
		group by p.segment
		)

select
	c.segment,
    c.product_count_2020,
    e.product_count_2021,
    e.product_count_2021 - c.product_count_2020 as difference
from cte2020 c
join cte2021 e
ON c.segment = e.segment
Order by difference desc;


-- 5.  Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, 
-- product_code 
-- product 
-- manufacturing_cost 

select
	p.product_code,
    p.product,
	m.manufacturing_cost
from dim_product p
join fact_manufacturing_cost m
	ON p.product_code = m.product_code
where m.manufacturing_cost = (
		select max(manufacturing_cost)
        from fact_manufacturing_cost)
OR m.manufacturing_cost =(
		select min(manufacturing_cost)
        from fact_manufacturing_cost)
order by manufacturing_cost desc;

-- Cleaner Advanced Version (Professional SQL)
-- Using window ranking (often preferred):
SELECT *
FROM (
    SELECT
        p.product_code,
        p.product,
        m.manufacturing_cost,
        RANK() OVER (ORDER BY m.manufacturing_cost) AS r_low,
        RANK() OVER (ORDER BY m.manufacturing_cost DESC) AS r_high
    FROM dim_product p
    JOIN fact_manufacturing_cost m
        ON p.product_code = m.product_code
) t
WHERE r_low = 1 OR r_high = 1;

-- 6.  Generate a report which contains the top 5 customers who received an average high  pre_invoice_discount_pct  for 
-- the  fiscal  year 2021  and in the Indian  market. 
-- The final output contains these fields, 
-- customer_code 
-- customer 
-- average_discount_percentage 

with India2021 AS
	(Select 
		c.customer_code,
		c.customer,
        c.platform,
        c.market,
        d.fiscal_year,
        d.pre_invoice_discount_pct
		from dim_customer c
		JOIN fact_pre_invoice_deductions d
			ON c.customer_code = d.customer_code
		where d.fiscal_year = 2021 and
			c.market = "India"
	)
    
select 
	customer_code,
    customer,
	avg(pre_invoice_discount_pct) as average_discount_percentage
from India2021
group by customer_code, customer
order by average_discount_percentage desc
limit 5;

-- 7.  Get the complete report of the Gross sales amount for the customer  “Atliq Exclusive”  for each month  .  
-- This analysis helps to  get an idea of low and high-performing months and take strategic decisions. 
-- The final report contains these columns: 
-- Month 
-- Year 
-- Gross sales Amount 

Select 
	MONTHNAME(s.date) as Month,
    s.fiscal_year as Year,
    c.customer,
    s.sold_quantity,
    p.gross_price,
    (s.sold_quantity * p.gross_price) As Gross_sales_Amount 
    
from fact_sales_monthly s
JOIN fact_gross_price p
	ON s.product_code = p.product_code
    
JOIN dim_customer c	
	ON s.customer_code = c.customer_code
    
where c.customer = "Atliq Exclusive";

-- 8.  In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity, 
-- Quarter 
-- total_sold_quantity 

SELECT 
	quarter(date) as Quarter,
    sum(sold_quantity) as total_sold_qty
FROM gdb023.fact_sales_monthly
where fiscal_year = 2020
group by quarter(date)
Order by total_sold_qty desc;

-- 9.  Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?  
-- The final output  contains these fields, 
-- channel 
-- gross_sales_mln 
-- percentage 

Select 
	c.channel,
    sum(s.sold_quantity * p.gross_price) As Gross_sales_Amount,
    
    ROUND(SUM(s.sold_quantity * p.gross_price) * 100 
     / SUM(SUM(s.sold_quantity * p.gross_price)) OVER()
     ,2) as Pct_contribution
     
from fact_sales_monthly s
JOIN fact_gross_price p
	ON s.product_code = p.product_code
    AND s.fiscal_year = p.fiscal_year
 JOIN dim_customer c	
	ON s.customer_code = c.customer_code
where s.fiscal_year = 2021
group by c.channel
order by Gross_sales_Amount desc;

-- 10.  Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields, 
-- division 
-- product_code 
-- product 
-- total_sold_quantity 
-- rank_order 

with product2021 AS
		( SELECT 
			s.product_code,
			SUM(s.sold_quantity) as Total_sold_qty,
			p.division,
			p.product,
            (dense_rank() over(partition by division order by SUM(s.sold_quantity) desc)) as rank_order
		FROM gdb023.fact_sales_monthly s
		JOIN dim_product p
			ON s.product_code = p.product_code
		where fiscal_year = 2021
        GROUP BY p.division,
		s.product_code,
		p.product
        )

select 
	division,
	product_code, 
	product, 
	Total_sold_qty, 
	rank_order  
from product2021
where rank_order <4;
 