/*
Assignment week 3
Author: Kai Hartley
Date: 2023-02-27
*/

-- Get Schema
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;


-- EASY
-- 1) Retrieve the first name, last name, and email address of 
    -- every customer in the database. Order the results alphabetically by last name.
SELECT first_name, last_name, email
FROM customer
ORDER BY last_name;


-- 2) List the name and unit price of all tracks that have a unit 
    -- price greater than $0.99. Order by unit price descending.
SELECT name, unit_price
FROM track
WHERE unit_price > 0.99
ORDER BY unit_price DESC;


-- 3) Find the total number of tracks in the database.
SELECT COUNT(track_id)              -- track_id is the primary key of the track table and wont have duplicates
FROM track; 


-- MEDIUM
-- 4) List each customer's full name (first + last) alongside the total number of invoices they have. 
    -- Only include customers who have placed more than 3 invoices. Order by invoice count descending.
SELECT c.first_name || ' ' || c.last_name AS customer_name, COUNT(i.invoice_id) AS invoice_count
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id              -- group by customer table cause grouping by invoice will always return 1 for each row
HAVING COUNT(i.invoice_id) > 3      -- filter the groupings
ORDER BY invoice_count DESC;


-- 5) Find the top 5 most purchased tracks (by quantity sold across all invoices). 
    -- Display the track name and total quantity sold.
SELECT t.name AS track_name, SUM(il.quantity) AS total_quantity_sold
FROM track t
JOIN invoice_line il ON t.track_id = il.track_id -- INNER JOIN to filter out NULL for tracks with no sales
GROUP BY t.track_id
ORDER BY total_quantity_sold DESC
LIMIT 5;


-- 6) List all albums along with the name of the artist who made them 
    -- and the total number of tracks on each album. Order by track count descending.
SELECT al.title AS album_name, ar.name AS artist_name, COUNT(t.track_id) AS total_tracks_on_album
FROM album al                                   -- artist_id has the constraint NOT NULL
JOIN artist ar ON al.artist_id = ar.artist_id   -- Doing a INNER JOIN here is ok because of constraint
LEFT JOIN track t ON al.album_id = t.album_id   -- 'list all albums' so all from album and only matching tracks
GROUP BY al.album_id, ar.artist_id              -- selecting columns from both tables, so both PKs are in GROUP BY
ORDER BY total_tracks_on_album DESC;


-- 7) Find all customers who are located in the same country as their assigned support representative (sales agent). 
    -- Return the customer's full name, the rep's full name, and the country.
SELECT 
    c.first_name || ' ' || c.last_name AS customer_name, 
    e.first_name || ' ' || e.last_name AS employee_name, 
    c.country
FROM customer c
JOIN employee e ON c.support_rep_id = e.employee_id AND e.country = c.country;  -- shortcut instead of doing WHERE


-- 8) Calculate the total revenue generated per genre. Display the genre name and total revenue, ordered by revenue descending.
WITH line_revenue AS (                                  -- creating a CTE to calculate revenue for each track to simplify query
    SELECT track_id, unit_price * quantity AS revenue
    FROM invoice_line
)                                                       -- use line_revenue for revenue/invoice
SELECT g.name AS genre_name, COALESCE(SUM(lr.revenue), 0) AS total_revenue      -- COALESCE to return 0 for NULL
FROM genre g
LEFT JOIN track t ON g.genre_id = t.genre_id            -- keeps all genre
LEFT JOIN line_revenue lr ON t.track_id = lr.track_id
GROUP BY g.genre_id
ORDER BY total_revenue DESC;


-- HARD
-- 9) Find the month-over-month revenue for the year 2021. 
    -- Display the month number, month name, and total revenue for each month. (Hint: use TO_CHAR or DATE_PART.)
SELECT 
    EXTRACT(MONTH FROM invoice_date) AS month_number,               -- month_number alias
    TO_CHAR(invoice_date, 'Month') AS month_name,       
    SUM(total) AS total_revenue
FROM invoice i
WHERE invoice_date >= '2021-01-01' AND invoice_date < '2022-01-01'  -- use original format to optimize query
GROUP BY month_number, month_name                                   -- postgres allows for alias reference from SELECT 
ORDER BY month_number;                                                 -- even if GROUP BY runs before SELECT


-- 10) Identify customers who have never purchased a track from the 'Rock' genre. 
    -- Return their full name and email. 
    -- (Hint: this is the same LEFT JOIN + IS NULL anti-join shape from this week's demo — a plain INNER JOIN can't express "this never happened.")
WITH rock_buyers AS (                                               -- subquery to determine rock_buyer customer_id
    SELECT DISTINCT i.customer_id
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE g.name = 'Rock'
)
SELECT c.first_name || ' ' || c.last_name AS customer_name, c.email
FROM customer c
LEFT JOIN rock_buyers rb ON c.customer_id = rb.customer_id          -- LEFT JOIN produces customers without matching rock_buyer records
WHERE rb.customer_id IS NULL;                                       -- IS NULL removes rock_buyer records with NULL customer_idORDER BY customer_name;                           


-- 11) For each country, find the single highest-spending customer. 
    -- Display the country, the customer's full name, and their total spend. 
    -- (A clean way to do this is a window function — RANK() or ROW_NUMBER() with PARTITION BY — though a subquery can also get you there. 
    -- If you go the window-function route: PostgreSQL's window functions tutorial and the window function reference.)
WITH customer_totals AS (                                                       -- subquery to determine customer_totals
    SELECT                                                                      -- save id, name, country, total
        c.customer_id, 
        c.first_name || ' ' || c.last_name AS customer_name, 
        c.country, SUM(i.total) AS total_spend
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
ranked_customers AS (                                                           -- subquery for ranking by country and spending
    SELECT 
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY total_spend DESC) AS   -- ROW_NUMBER() OVER assigns a unique sequential integer to rows
        spend_rank,                                                             -- PARTITION BY divides the result set into groups
        country, customer_name, total_spend                                     -- ORDER BY is req. in ROW_NUMBER()
    FROM customer_totals
)
SELECT country, customer_name, total_spend
FROM ranked_customers
WHERE spend_rank = 1;

-- 12)Find all tracks that have never been purchased. Display the track name, album title, and artist name.
SELECT t.name, al.title, ar.name AS artist_name
FROM track t
LEFT JOIN album al ON t.album_id = al.album_id
LEFT JOIN artist ar ON al.artist_id = ar.artist_id
WHERE NOT EXISTS (                                                              -- WHERE NOT EXISTS returns true as soon as a match is found
    SELECT 1 FROM invoice_line il WHERE il.track_id = t.track_id
);
