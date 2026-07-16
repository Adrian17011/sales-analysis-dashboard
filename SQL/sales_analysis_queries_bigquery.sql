/*
====================================================================
SUPERSTORE SALES PERFORMANCE ANALYSIS
Author: Luis Adrian Gamez Saucedo
Platform: Google BigQuery
Dataset: Sales.superstore_sales
SQL dialect: GoogleSQL (Standard SQL)
====================================================================

ABOUT THIS FILE
This script contains the main SQL queries used to explore the dataset,
validate data quality, calculate business KPIs, and analyze sales by
time, geography, customer, product, and shipping method.

IMPORTANT
The queries assume that the BigQuery columns use underscores, for example:
Order_ID, Order_Date, Ship_Date, Customer_ID, Product_Name and Sub_Category.

If your table uses a different project or dataset name, replace:
`Sales.superstore_sales`

with:
`your_project_id.Sales.superstore_sales`
*/


-- ==================================================================
-- SECTION 1: DATA EXPLORATION AND QUALITY VALIDATION
-- ==================================================================


/*
QUERY 1: Dataset overview

Purpose:
Confirm the number of records in the dataset and review the date range
covered by the analysis.

Business value:
Validates the scope of the project before calculating performance metrics.
*/

SELECT
  COUNT(*) AS total_rows,
  MIN(Order_Date) AS first_order_date,
  MAX(Order_Date) AS last_order_date
FROM `Sales.superstore_sales`;


/*
QUERY 2: Missing-value review

Purpose:
Count null values in key fields that could affect the analysis.

Business value:
Identifies incomplete records before producing KPIs or dashboards.
*/

SELECT
  COUNTIF(Order_ID IS NULL) AS missing_order_ids,
  COUNTIF(Order_Date IS NULL) AS missing_order_dates,
  COUNTIF(Customer_ID IS NULL) AS missing_customer_ids,
  COUNTIF(Product_ID IS NULL) AS missing_product_ids,
  COUNTIF(Region IS NULL) AS missing_regions,
  COUNTIF(Postal_Code IS NULL) AS missing_postal_codes,
  COUNTIF(Sales IS NULL) AS missing_sales_values
FROM `Sales.superstore_sales`;


/*
QUERY 3: Exact duplicate check

Purpose:
Detect records that are completely duplicated across all columns.

Business value:
Prevents duplicated transactions from inflating revenue and order metrics.
*/

SELECT
  Row_ID,
  Order_ID,
  Order_Date,
  Ship_Date,
  Ship_Mode,
  Customer_ID,
  Customer_Name,
  Segment,
  Country,
  City,
  State,
  Postal_Code,
  Region,
  Product_ID,
  Category,
  Sub_Category,
  Product_Name,
  Sales,
  COUNT(*) AS duplicate_count
FROM `Sales.superstore_sales`
GROUP BY
  Row_ID,
  Order_ID,
  Order_Date,
  Ship_Date,
  Ship_Mode,
  Customer_ID,
  Customer_Name,
  Segment,
  Country,
  City,
  State,
  Postal_Code,
  Region,
  Product_ID,
  Category,
  Sub_Category,
  Product_Name,
  Sales
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


/*
QUERY 4: Shipping-time validation

Purpose:
Calculate the minimum, maximum, and average number of days between the
order date and ship date.

Business value:
Helps detect invalid dates and provides an overview of fulfillment speed.
*/

SELECT
  MIN(DATE_DIFF(Ship_Date, Order_Date, DAY)) AS minimum_shipping_days,
  MAX(DATE_DIFF(Ship_Date, Order_Date, DAY)) AS maximum_shipping_days,
  ROUND(AVG(DATE_DIFF(Ship_Date, Order_Date, DAY)), 2)
    AS average_shipping_days
FROM `Sales.superstore_sales`;


/*
QUERY 5: Potential invalid shipping dates

Purpose:
Find records in which the shipping date occurs before the order date.

Business value:
Flags date-quality problems that could distort operational analysis.
*/

SELECT
  Order_ID,
  Order_Date,
  Ship_Date,
  DATE_DIFF(Ship_Date, Order_Date, DAY) AS shipping_days
FROM `Sales.superstore_sales`
WHERE Ship_Date < Order_Date
ORDER BY shipping_days;


/*
QUERY 6: Sales-value distribution

Purpose:
Review minimum, maximum, average, and approximate median line-item sales.

Business value:
Provides context for typical transaction size and helps identify extreme values.
*/

SELECT
  ROUND(MIN(Sales), 2) AS minimum_line_sales,
  ROUND(MAX(Sales), 2) AS maximum_line_sales,
  ROUND(AVG(Sales), 2) AS average_line_sales,
  ROUND(APPROX_QUANTILES(Sales, 100)[OFFSET(50)], 2)
    AS approximate_median_line_sales
FROM `Sales.superstore_sales`;


-- ==================================================================
-- SECTION 2: CORE BUSINESS KPIs
-- ==================================================================


/*
QUERY 7: Executive KPI summary

Purpose:
Calculate total revenue, total orders, unique customers, average order
value, and average revenue per customer.

Business value:
Provides a concise overview of the company's sales performance.
*/

WITH order_totals AS (
  SELECT
    Order_ID,
    SUM(Sales) AS order_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Order_ID
)

SELECT
  ROUND((SELECT SUM(Sales)
         FROM `Sales.superstore_sales`), 2) AS total_revenue,

  (SELECT COUNT(DISTINCT Order_ID)
   FROM `Sales.superstore_sales`) AS total_orders,

  (SELECT COUNT(DISTINCT Customer_ID)
   FROM `Sales.superstore_sales`) AS unique_customers,

  ROUND(AVG(order_revenue), 2) AS average_order_value,

  ROUND(
    (SELECT SUM(Sales) FROM `Sales.superstore_sales`)
    /
    (SELECT COUNT(DISTINCT Customer_ID)
     FROM `Sales.superstore_sales`),
    2
  ) AS average_revenue_per_customer
FROM order_totals;


/*
QUERY 8: Average purchase frequency

Purpose:
Calculate the average number of distinct orders placed per customer.

Business value:
Measures how frequently customers purchase from the business.
*/

WITH customer_orders AS (
  SELECT
    Customer_ID,
    COUNT(DISTINCT Order_ID) AS order_count
  FROM `Sales.superstore_sales`
  GROUP BY Customer_ID
)

SELECT
  ROUND(AVG(order_count), 2) AS average_orders_per_customer
FROM customer_orders;


-- ==================================================================
-- SECTION 3: TIME AND TREND ANALYSIS
-- ==================================================================


/*
QUERY 9: Annual sales performance

Purpose:
Summarize revenue and order volume by year.

Business value:
Shows long-term growth or decline in commercial performance.
*/

SELECT
  EXTRACT(YEAR FROM Order_Date) AS order_year,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders,
  ROUND(
    SAFE_DIVIDE(SUM(Sales), COUNT(DISTINCT Order_ID)),
    2
  ) AS average_order_value
FROM `Sales.superstore_sales`
GROUP BY order_year
ORDER BY order_year;


/*
QUERY 10: Monthly sales trend

Purpose:
Calculate revenue and orders for every year-month combination.

Business value:
Reveals seasonality and supports monthly performance monitoring.
*/

SELECT
  DATE_TRUNC(Order_Date, MONTH) AS sales_month,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders
FROM `Sales.superstore_sales`
GROUP BY sales_month
ORDER BY sales_month;


/*
QUERY 11: Overall seasonality by calendar month

Purpose:
Aggregate all years by month number to identify the strongest and weakest
months of the year.

Business value:
Supports campaign planning, inventory preparation, and seasonal budgeting.
*/

SELECT
  EXTRACT(MONTH FROM Order_Date) AS month_number,
  FORMAT_DATE('%B', DATE(2000, EXTRACT(MONTH FROM Order_Date), 1))
    AS month_name,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders
FROM `Sales.superstore_sales`
GROUP BY month_number, month_name
ORDER BY total_revenue DESC;


/*
QUERY 12: Year-over-year revenue growth

Purpose:
Compare each year's revenue with the previous year using the LAG window
function.

Business value:
Quantifies annual growth and makes changes in performance easy to evaluate.

Advanced concept:
CTE + LAG window function + SAFE_DIVIDE.
*/

WITH yearly_sales AS (
  SELECT
    EXTRACT(YEAR FROM Order_Date) AS order_year,
    SUM(Sales) AS annual_revenue
  FROM `Sales.superstore_sales`
  GROUP BY order_year
),

yearly_comparison AS (
  SELECT
    order_year,
    annual_revenue,
    LAG(annual_revenue) OVER (ORDER BY order_year)
      AS previous_year_revenue
  FROM yearly_sales
)

SELECT
  order_year,
  ROUND(annual_revenue, 2) AS annual_revenue,
  ROUND(previous_year_revenue, 2) AS previous_year_revenue,
  ROUND(
    SAFE_DIVIDE(
      annual_revenue - previous_year_revenue,
      previous_year_revenue
    ) * 100,
    2
  ) AS year_over_year_growth_percent
FROM yearly_comparison
ORDER BY order_year;


/*
QUERY 13: Monthly running revenue total

Purpose:
Calculate cumulative revenue over time.

Business value:
Shows how revenue accumulates throughout the analysis period and helps
compare progress against annual targets.

Advanced concept:
CTE + SUM window function.
*/

WITH monthly_sales AS (
  SELECT
    DATE_TRUNC(Order_Date, MONTH) AS sales_month,
    SUM(Sales) AS monthly_revenue
  FROM `Sales.superstore_sales`
  GROUP BY sales_month
)

SELECT
  sales_month,
  ROUND(monthly_revenue, 2) AS monthly_revenue,
  ROUND(
    SUM(monthly_revenue) OVER (ORDER BY sales_month),
    2
  ) AS cumulative_revenue
FROM monthly_sales
ORDER BY sales_month;


-- ==================================================================
-- SECTION 4: GEOGRAPHICAL AND SEGMENT ANALYSIS
-- ==================================================================


/*
QUERY 14: Sales by region

Purpose:
Compare revenue, customers, and orders across regions.

Business value:
Identifies the strongest and weakest geographical markets.
*/

SELECT
  Region,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders,
  COUNT(DISTINCT Customer_ID) AS unique_customers,
  ROUND(
    SAFE_DIVIDE(SUM(Sales), COUNT(DISTINCT Order_ID)),
    2
  ) AS average_order_value
FROM `Sales.superstore_sales`
GROUP BY Region
ORDER BY total_revenue DESC;


/*
QUERY 15: Sales by state with regional ranking

Purpose:
Rank states by revenue within their respective region.

Business value:
Allows regional managers to identify their top-performing state markets.

Advanced concept:
CTE + RANK window function with PARTITION BY.
*/

WITH state_sales AS (
  SELECT
    Region,
    State,
    SUM(Sales) AS state_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Region, State
)

SELECT
  Region,
  State,
  ROUND(state_revenue, 2) AS state_revenue,
  RANK() OVER (
    PARTITION BY Region
    ORDER BY state_revenue DESC
  ) AS revenue_rank_within_region
FROM state_sales
ORDER BY Region, revenue_rank_within_region;


/*
QUERY 16: Sales by customer segment

Purpose:
Compare revenue contribution and average order value across Consumer,
Corporate, and Home Office segments.

Business value:
Helps marketing and sales teams adapt strategies to each customer group.
*/

WITH segment_orders AS (
  SELECT
    Segment,
    Order_ID,
    SUM(Sales) AS order_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Segment, Order_ID
)

SELECT
  Segment,
  ROUND(SUM(order_revenue), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders,
  ROUND(AVG(order_revenue), 2) AS average_order_value
FROM segment_orders
GROUP BY Segment
ORDER BY total_revenue DESC;


-- ==================================================================
-- SECTION 5: PRODUCT ANALYSIS
-- ==================================================================


/*
QUERY 17: Sales by category and sub-category

Purpose:
Compare revenue and order frequency across product groups.

Business value:
Supports assortment decisions and identifies product areas with stronger
commercial demand.
*/

SELECT
  Category,
  Sub_Category,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS order_frequency
FROM `Sales.superstore_sales`
GROUP BY Category, Sub_Category
ORDER BY total_revenue DESC;


/*
QUERY 18: Category revenue contribution

Purpose:
Calculate each category's percentage contribution to total revenue.

Business value:
Shows how dependent the business is on each major product category.

Advanced concept:
Window aggregation over grouped results.
*/

SELECT
  Category,
  ROUND(SUM(Sales), 2) AS category_revenue,
  ROUND(
    SAFE_DIVIDE(
      SUM(Sales),
      SUM(SUM(Sales)) OVER ()
    ) * 100,
    2
  ) AS revenue_share_percent
FROM `Sales.superstore_sales`
GROUP BY Category
ORDER BY category_revenue DESC;


/*
QUERY 19: Top 10 products by revenue

Purpose:
Identify the products that generated the most sales.

Business value:
Helps prioritize inventory availability, promotions, and product strategy.
*/

SELECT
  Product_ID,
  Product_Name,
  Category,
  Sub_Category,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS order_frequency
FROM `Sales.superstore_sales`
GROUP BY Product_ID, Product_Name, Category, Sub_Category
ORDER BY total_revenue DESC
LIMIT 10;


/*
QUERY 20: Top three products within each category

Purpose:
Rank products inside each category and return the three highest-revenue
products per category.

Business value:
Identifies category leaders without allowing one large category to dominate
the overall product ranking.

Advanced concept:
CTE + ROW_NUMBER window function + QUALIFY.
*/

WITH product_sales AS (
  SELECT
    Category,
    Product_ID,
    Product_Name,
    SUM(Sales) AS product_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Category, Product_ID, Product_Name
)

SELECT
  Category,
  Product_ID,
  Product_Name,
  ROUND(product_revenue, 2) AS product_revenue,
  ROW_NUMBER() OVER (
    PARTITION BY Category
    ORDER BY product_revenue DESC
  ) AS category_rank
FROM product_sales
QUALIFY category_rank <= 3
ORDER BY Category, category_rank;


/*
QUERY 21: Low-performing products with sufficient order history

Purpose:
Find products with relatively low revenue that appeared in at least five
distinct orders.

Business value:
Highlights products that may require pricing, promotion, or assortment review.

SQL concept:
HAVING filters aggregated results.
*/

SELECT
  Product_ID,
  Product_Name,
  Category,
  Sub_Category,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS order_frequency
FROM `Sales.superstore_sales`
GROUP BY Product_ID, Product_Name, Category, Sub_Category
HAVING COUNT(DISTINCT Order_ID) >= 5
ORDER BY total_revenue ASC
LIMIT 20;


-- ==================================================================
-- SECTION 6: CUSTOMER ANALYSIS
-- ==================================================================


/*
QUERY 22: Top 10 customers by revenue

Purpose:
Identify the customers who contributed the most revenue.

Business value:
Supports account prioritization, retention efforts, and targeted offers.
*/

SELECT
  Customer_ID,
  Customer_Name,
  Segment,
  ROUND(SUM(Sales), 2) AS total_revenue,
  COUNT(DISTINCT Order_ID) AS total_orders,
  ROUND(
    SAFE_DIVIDE(SUM(Sales), COUNT(DISTINCT Order_ID)),
    2
  ) AS average_order_value
FROM `Sales.superstore_sales`
GROUP BY Customer_ID, Customer_Name, Segment
ORDER BY total_revenue DESC
LIMIT 10;


/*
QUERY 23: Customer value segmentation

Purpose:
Classify customers into High, Medium, and Low value groups based on total
revenue.

Business value:
Creates a simple customer segmentation that can support differentiated
marketing and retention strategies.

Advanced concept:
CTE + CASE expression.
*/

WITH customer_sales AS (
  SELECT
    Customer_ID,
    Customer_Name,
    SUM(Sales) AS customer_revenue,
    COUNT(DISTINCT Order_ID) AS total_orders
  FROM `Sales.superstore_sales`
  GROUP BY Customer_ID, Customer_Name
)

SELECT
  Customer_ID,
  Customer_Name,
  ROUND(customer_revenue, 2) AS customer_revenue,
  total_orders,
  CASE
    WHEN customer_revenue >= 5000 THEN 'High Value'
    WHEN customer_revenue >= 2000 THEN 'Medium Value'
    ELSE 'Low Value'
  END AS customer_value_segment
FROM customer_sales
ORDER BY customer_revenue DESC;


/*
QUERY 24: Revenue concentration among the top 10 percent of customers

Purpose:
Measure the percentage of total revenue generated by the highest-value
10 percent of customers.

Business value:
Indicates whether revenue is highly concentrated among a small customer group.

Advanced concept:
CTE + NTILE window function.
*/

WITH customer_sales AS (
  SELECT
    Customer_ID,
    SUM(Sales) AS customer_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Customer_ID
),

ranked_customers AS (
  SELECT
    Customer_ID,
    customer_revenue,
    NTILE(10) OVER (ORDER BY customer_revenue DESC) AS revenue_decile
  FROM customer_sales
)

SELECT
  ROUND(SUM(customer_revenue), 2) AS total_revenue,
  ROUND(
    SUM(IF(revenue_decile = 1, customer_revenue, 0)),
    2
  ) AS top_10_percent_customer_revenue,
  ROUND(
    SAFE_DIVIDE(
      SUM(IF(revenue_decile = 1, customer_revenue, 0)),
      SUM(customer_revenue)
    ) * 100,
    2
  ) AS top_10_percent_revenue_share
FROM ranked_customers;


/*
QUERY 25: Customer purchasing behavior

Purpose:
Summarize first purchase, most recent purchase, number of orders, and total
revenue for every customer.

Business value:
Provides a basic customer-history view that can support retention analysis.
*/

SELECT
  Customer_ID,
  Customer_Name,
  MIN(Order_Date) AS first_order_date,
  MAX(Order_Date) AS most_recent_order_date,
  COUNT(DISTINCT Order_ID) AS total_orders,
  ROUND(SUM(Sales), 2) AS total_revenue
FROM `Sales.superstore_sales`
GROUP BY Customer_ID, Customer_Name
ORDER BY total_revenue DESC;


-- ==================================================================
-- SECTION 7: SHIPPING AND OPERATIONS ANALYSIS
-- ==================================================================


/*
QUERY 26: Shipping performance by ship mode

Purpose:
Compare order volume, revenue, and average shipping time across ship modes.

Business value:
Helps evaluate whether shipping options differ in operational speed and
commercial importance.
*/

WITH order_shipping AS (
  SELECT
    Order_ID,
    Ship_Mode,
    MIN(Order_Date) AS order_date,
    MAX(Ship_Date) AS ship_date,
    SUM(Sales) AS order_revenue
  FROM `Sales.superstore_sales`
  GROUP BY Order_ID, Ship_Mode
)

SELECT
  Ship_Mode,
  COUNT(*) AS total_orders,
  ROUND(SUM(order_revenue), 2) AS total_revenue,
  ROUND(
    AVG(DATE_DIFF(ship_date, order_date, DAY)),
    2
  ) AS average_shipping_days
FROM order_shipping
GROUP BY Ship_Mode
ORDER BY total_orders DESC;


/*
QUERY 27: Shipping-speed classification

Purpose:
Classify orders according to the number of days required for shipping.

Business value:
Provides an easy operational distribution of fast, standard, and slow
fulfillment.

Advanced concept:
Order-level CTE + CASE expression.
*/

WITH order_shipping AS (
  SELECT
    Order_ID,
    MIN(Order_Date) AS order_date,
    MAX(Ship_Date) AS ship_date
  FROM `Sales.superstore_sales`
  GROUP BY Order_ID
)

SELECT
  CASE
    WHEN DATE_DIFF(ship_date, order_date, DAY) <= 2 THEN 'Fast: 0-2 days'
    WHEN DATE_DIFF(ship_date, order_date, DAY) <= 5 THEN 'Standard: 3-5 days'
    ELSE 'Slow: 6+ days'
  END AS shipping_speed_group,
  COUNT(*) AS total_orders,
  ROUND(
    SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
    2
  ) AS order_share_percent
FROM order_shipping
GROUP BY shipping_speed_group
ORDER BY total_orders DESC;


/*
====================================================================
END OF FILE
====================================================================
*/
