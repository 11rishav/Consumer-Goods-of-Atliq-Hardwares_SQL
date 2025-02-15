SELECT market
FROM dim_customer 
WHERE customer = "Atliq Exclusive" AND region = "APAC";


WITH product_cnt_2020 AS (
    SELECT COUNT(DISTINCT s.product_code) AS unique_products_2020
    FROM fact_sales_monthly s
    WHERE YEAR(s.date) = 2020
),
product_cnt_2021 AS (
    SELECT COUNT(DISTINCT s.product_code) AS unique_products_2021
    FROM fact_sales_monthly s
    WHERE YEAR(s.date) = 2021
)
SELECT 
    product_cnt_2020.unique_products_2020, 
    product_cnt_2021.unique_products_2021,
    ROUND(
        (product_cnt_2021.unique_products_2021 - product_cnt_2020.unique_products_2020) * 100.0 
        / NULLIF(product_cnt_2020.unique_products_2020, 0), 
    2) AS pct_change
FROM product_cnt_2020
CROSS JOIN product_cnt_2021;


SELECT segment, COUNT(product_code) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


WITH product_cnt_2020 AS 
		(SELECT p.segment,
		       COUNT(DISTINCT s.product_code) AS unique_products_2020
			   FROM fact_sales_monthly s
               JOIN dim_product p ON s.product_code = p.product_code
               WHERE s.fiscal_year = 2020
               GROUP BY p.segment
               ),
product_cnt_2021 AS
        (SELECT p.segment,
		       COUNT(DISTINCT s.product_code) AS unique_products_2021
			   FROM fact_sales_monthly s
               JOIN dim_product p ON s.product_code = p.product_code
               WHERE s.fiscal_year = 2021
               GROUP BY p.segment)

SELECT product_cnt_2020.segment, product_cnt_2020.unique_products_2020, product_cnt_2021.unique_products_2021,
       ( product_cnt_2021.unique_products_2021 - product_cnt_2020.unique_products_2020) as difference
FROM product_cnt_2020 JOIN product_cnt_2021 ON product_cnt_2020.segment = product_cnt_2021.segment
ORDER BY difference DESC;


WITH max_cost AS
			(SELECT p.product_code, p.product, m.manufacturing_cost
             from fact_manufacturing_cost m 
             JOIN dim_product p ON m.product_code = p.product_code
             ORDER BY m.manufacturing_cost DESC 
             LIMIT 1),
min_cost AS
			(SELECT p.product_code, p.product, m.manufacturing_cost
             from fact_manufacturing_cost m 
             JOIN dim_product p ON m.product_code = p.product_code
             ORDER BY m.manufacturing_cost ASC 
             LIMIT 1)

SELECT * FROM max_cost
UNION ALL
SELECT * from min_cost;


SELECT 
       pinv.customer_code, 
       c.customer,
       AVG(pinv.pre_invoice_discount_pct) AS avg_discount
FROM fact_pre_invoice_deductions pinv 
JOIN dim_customer c
ON pinv.customer_code = c.customer_code
WHERE pinv.fiscal_year = 2021 AND c.market = 'India'
GROUP BY pinv.customer_code, c.customer
ORDER BY avg_discount DESC
LIMIT 5;


SELECT 
     MONTH(fsm.date) AS Month, 
     YEAR(fsm.date) AS Year,
     ROUND(SUM((g.gross_price*fsm.sold_quantity)),2) as total_gross_amount
FROM fact_sales_monthly fsm 
JOIN fact_gross_price g
ON fsm.product_code = g.product_code
JOIN dim_customer c
ON c.customer_code = fsm.customer_code 
WHERE c.customer = "Atliq Exclusive"
GROUP BY  Year, Month
ORDER BY Year, Month;


SELECT 
    CASE 
        WHEN MONTH(s.date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(s.date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(s.date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(s.date) IN (6, 7, 8) THEN 'Q4'
    END AS Quarter,
    SUM(s.sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly s
WHERE fiscal_year = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC
LIMIT 1;


WITH Channel_gross_price AS 
(SELECT 
		c.channel AS Channel, 
        SUM((g.gross_price*s.sold_quantity)/1000000) as Gross_price
FROM fact_sales_monthly s
JOIN fact_gross_price g ON s.product_code = g.product_code
JOIN dim_customer c ON s.customer_code = c.customer_code
WHERE s.fiscal_year = 2021
GROUP BY Channel),
Total_gross_price AS 
(
    SELECT SUM(Gross_price) AS Total_gross_price
    FROM Channel_gross_price
)
SELECT 
		cgp.Channel AS Channel,
        cgp.Gross_price AS gross_price_mln,
        ROUND((cgp.Gross_price*100/tgp.Total_gross_price),2) AS pct_contribution
FROM Channel_gross_price cgp
CROSS JOIN Total_gross_price tgp
ORDER BY gross_price_mln DESC
LIMIT 1;



WITH cte1 AS (
    SELECT 
        p.division AS Division, 
        p.product_code AS Product_Code, 
        p.product AS Product,
        SUM(s.sold_quantity) AS Sold_Quantity
    FROM fact_sales_monthly s 
    JOIN dim_product p 
        ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product
),
ranked_data AS (
    SELECT 
        cte1.*, 
        DENSE_RANK() OVER (PARTITION BY cte1.Division ORDER BY cte1.Sold_Quantity DESC) AS rank_order
    FROM cte1
)
SELECT * 
FROM ranked_data
WHERE rank_order <= 3
ORDER BY Division, rank_order, Sold_Quantity DESC;


