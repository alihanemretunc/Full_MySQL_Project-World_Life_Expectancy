-- World Life Expectancy Project (Data Cleaning and Exploratory Data Analysis) 

-- 4 steps in data cleaning:
	-- 1) Removing Duplicates
	-- 2) Standardizing Data
	-- 3) Handling NULL Values
    -- 4) Removing Possible Rows and Columns
    
-- But before any of these steps, one should generate a backup table just in case.

-- You can do that through Table Data Import Wizard (right click on your schema)

-- Now, let's start.

SELECT * FROM world_life_expectancy; -- this is how our data looks like

SELECT COUNT(1)
FROM world_life_expectancy; -- 2941 rows in total

-- It's time to start from step 1: removing duplicates

-- you may concatenate columns to see the duplicates easily
SELECT Country, `Year`, CONCAT(Country, `Year`), COUNT(CONCAT(Country, `Year`))
FROM world_life_expectancy
GROUP BY Country, `Year`, CONCAT(Country, `Year`)
HAVING COUNT(CONCAT(Country, `Year`)) > 1;
-- see that there are duplicates (check the counts)

-- let's generate a row_num column in a subquery 
-- so that we can delete the duplicates through the row_id column  

SELECT * FROM (
SELECT Row_ID,
CONCAT(Country, `Year`),
ROW_NUMBER() OVER(PARTITION BY CONCAT(Country, `Year`) ORDER BY CONCAT(Country, `Year`)) AS Row_Num
FROM world_life_expectancy) Row_table
WHERE Row_Num > 1;

-- remove duplicates by the delete method

DELETE FROM world_life_expectancy
WHERE Row_ID IN 
(SELECT Row_ID FROM 
(
SELECT Row_ID,
CONCAT(Country, `Year`),
ROW_NUMBER() OVER(PARTITION BY CONCAT(Country, `Year`) ORDER BY CONCAT(Country, `Year`)) AS Row_Num
FROM world_life_expectancy) Row_table
WHERE Row_Num > 1
);

-- see that 3 rows are deleted
SELECT COUNT(1)
FROM world_life_expectancy;

-- Step 2-3 together: Standardizing & NULL Value Check 

-- There are blank values 
-- in the `Status` and `Life Expectancy` columns

SELECT COUNT(Status)
FROM world_life_expectancy
WHERE Status = '';

-- Okay, we can update the blank status values by checking the distinct countries. 
-- For example, Afghanistan is a developing country by the table, 
-- so the blanks in the status field matching Afghanistan should be "Developing" as well.
 
SELECT DISTINCT(Status) 
FROM world_life_expectancy
WHERE Status <> '';

SELECT DISTINCT(Country)
FROM world_life_expectancy
WHERE Status = 'Developing';

-- Don't try to update with subqueries though.
-- It is not supported with the update command.

UPDATE world_life_expectancy   # gives an error because update doesn't allow subqueries
SET Status = 'Developing'
WHERE Country IN (SELECT DISTINCT(Country)
FROM world_life_expectancy
WHERE Status = 'Developing'); 

-- See the correct method below
-- for both status values

UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developing'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developing';

UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developed'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developed';

-- no blank status values now

SELECT *
FROM world_life_expectancy
WHERE Status = '';


-- Let's deal with the life expectancy too
-- see that there 2 blank rows
SELECT *
FROM world_life_expectancy
WHERE `Life expectancy`= '';

-- To deal with this, we need a self join
-- the query below takes the average of two values for the blank cells:
-- AVG(the value one row above + the value one row below)
-- Notice that years are in descending order, which is the key in this query

SELECT t1.Country, t1.`Year`, t1.`Life expectancy`, 
t2.Country, t2.`Year`, t2.`Life expectancy`,
t3.Country, t3.`Year`, t3.`Life expectancy`,
ROUND((t2.`Life expectancy` + t3.`Life expectancy`) / 2, 1)
FROM world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
    AND t1.`Year` = t2.`Year` - 1
JOIN world_life_expectancy t3
	ON t1.Country = t3.Country
    AND t1.`Year` = t3.`Year` + 1
WHERE t1.`Life expectancy` = '';

-- Update accordingly

UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
    AND t1.`Year` = t2.`Year` - 1
JOIN world_life_expectancy t3
	ON t1.Country = t3.Country
    AND t1.`Year` = t3.`Year` + 1
SET t1.`Life expectancy` = ROUND((t2.`Life expectancy` + t3.`Life expectancy`) / 2, 1)
WHERE t1.`Life expectancy` = '';


-- Finally, some fresh air!
-- No more blank values

SELECT *
FROM world_life_expectancy
WHERE `Life expectancy`= '';

-- What's coming next is exploratory data analysis...

-- Well, just check what's going on in the table first
-- General statistics and data literacy concepts can help

-- here is an aggregated table
SELECT Country, 
MIN(`Life Expectancy`), 
MAX(`Life Expectancy`),
ROUND(MAX(`Life Expectancy`) - MIN(`Life Expectancy`), 1) AS Life_increase_15_Years -- dataset has 15 distinct years 
FROM world_life_expectancy
GROUP BY Country
HAVING MIN(`Life Expectancy`) <> 0 AND MAX(`Life Expectancy`) <> 0 -- so that average is safe from all the added zeros
ORDER BY Life_increase_15_Years DESC;

-- Average life expectancy by year
SELECT `Year`, ROUND(AVG(`Life Expectancy`), 2)
FROM world_life_expectancy
WHERE `Life Expectancy` <> 0
GROUP BY `Year`
ORDER BY `Year`;

-- Here GDP means 
-- "total market value of the goods and services 
-- produced by a country's economy during a specified period of time"

-- Average life expectancy and GDP by country
SELECT Country, ROUND(AVG(`Life Expectancy`), 1) AS Life_Exp, ROUND(AVG(GDP), 1) AS GDP
FROM world_life_expectancy
GROUP BY Country
HAVING Life_Exp > 0 AND GDP > 0
ORDER BY GDP DESC;

-- Set a high GDP value around the median
-- Any correlation?
SELECT 
SUM(CASE WHEN GDP >= 1500 THEN 1 ELSE 0 END) AS High_GDP_Count,
AVG(CASE WHEN GDP >= 1500 THEN `Life Expectancy` ELSE NULL END) High_GDP_life_exp,
SUM(CASE WHEN GDP < 1500 THEN 1 ELSE 0 END) AS Low_GDP_Count,
AVG(CASE WHEN GDP < 1500 THEN `Life Expectancy` ELSE NULL END) Low_GDP_life_exp
FROM world_life_expectancy;

-- Average life expectancy by status
SELECT Status, ROUND(AVG(`Life Expectancy`), 1)
FROM world_life_expectancy
GROUP BY Status;

-- Always check the count if you're looking at the average
-- because data might be skewed
-- for example, the count is much lower for the developed countries 
-- see below

SELECT Status, COUNT(DISTINCT(Country)), ROUND(AVG(`Life Expectancy`), 1)
FROM world_life_expectancy
GROUP BY Status;

-- apparently high BMI doesn't reduce the life expectancy
-- Not the most intuitive thing...

SELECT Country, ROUND(AVG(`Life Expectancy`), 1) AS Life_Exp, ROUND(AVG(BMI), 1) AS BMI
FROM world_life_expectancy
GROUP BY Country
HAVING Life_Exp > 0 AND BMI > 0
ORDER BY BMI DESC;

-- Turkey's life expectancy constantly increased between 2011 and 2022
SELECT Country,
`Year`,
`Life Expectancy`,
`Adult Mortality`,
SUM(`Adult Mortality`) OVER(PARTITION BY Country ORDER BY `Year`) AS Rolling_Total
FROM world_life_expectancy
WHERE Country LIKE '%Turkey%';

-- The main idea is to detect correlations in exploratory data analysis
-- To do that, never forget the human factor.
-- Especially, human behavior and psychology,
-- and what affects those.

-- THE END