# World Life Expectancy Project 

#1. Explore the Data

-- Explore the overall structure and summary of the data
SELECT
    MIN(Year) AS FirstYear,
    MAX(Year) AS LastYear,
    COUNT(DISTINCT Country) AS NumCountries
FROM worldlifexpectancy;

-- Check for any missing or null values in important columns
SELECT
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN Lifeexpectancy IS NULL OR Lifeexpectancy = '' THEN 1 ELSE 0 END) AS MissingLifeExpectancy,
    SUM(CASE WHEN GDP IS NULL THEN 1 ELSE 0 END) AS MissingGDP
FROM worldlifexpectancy;

-- Initial exploration to understand data distribution for key metrics
SELECT
    Country,
    AVG(CAST(Lifeexpectancy AS FLOAT)) AS AvgLifeExpectancy,
    AVG(GDP) AS AvgGDP
FROM worldlifexpectancy
GROUP BY Country
ORDER BY AvgLifeExpectancy DESC;


## 2. Clean the Data


-- Correcting data types for numerical fields that are stored as strings
ALTER TABLE worldlifexpectancy
  MODIFY COLUMN Lifeexpectancy FLOAT,
  MODIFY COLUMN AdultMortality INT,
  MODIFY COLUMN infantdeaths INT,
  MODIFY COLUMN `under-fivedeaths` INT;
  
--  rename the column
ALTER TABLE worldlifexpectancy
  CHANGE `under-fivedeaths` under_fivedeaths INT;


-- Check for any negative values in columns where it doesn't make sense to have negative
SELECT * 
FROM worldlifexpectancy
WHERE Lifeexpectancy < 0 OR AdultMortality < 0 OR infantdeaths < 0 OR under_fivedeaths < 0;

-- Example of setting default values for missing life expectancy
UPDATE worldlifexpectancy
SET Lifeexpectancy = (SELECT AVG(Lifeexpectancy) FROM worldlifexpectancy WHERE Lifeexpectancy IS NOT NULL)
WHERE Lifeexpectancy IS NULL;

-- Alternatively, remove rows with critical missing information
DELETE FROM worldlifexpectancy
WHERE Lifeexpectancy IS NULL OR GDP IS NULL;



# find duplicate rows 
SELECT Row_ID
FROM (
SELECT ROW_ID,
CONCAT(Country,Year),
ROW_NUMBER() OVER(PARTITION BY CONCAT(Country,Year) ORDER BY CONCAT(Country,Year)) ROW_NUM
FROM worldlifexpectancy) AS ROW_TABLE
WHERE ROW_NUM > 1;

# Delete the duplicated rows 
DELETE FROM worldlifexpectancy
WHERE 
     ROW_ID IN (

SELECT Row_ID
FROM (
SELECT ROW_ID,
CONCAT(Country,Year),
ROW_NUMBER() OVER(PARTITION BY CONCAT(Country,Year) ORDER BY CONCAT(Country,Year)) ROW_NUM
FROM worldlifexpectancy) AS ROW_TABLE
WHERE ROW_NUM > 1 );
# Fill null values 


UPDATE worldlifexpectancy t1 
JOIN worldlifexpectancy t2 
     on t1.Country = t2.Country 
SET t1.Status = 'Developing'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developing'
;

UPDATE worldlifexpectancy t1 
JOIN worldlifexpectancy t2 
     on t1.Country = t2.Country 
SET t1.Status = 'Developed'
WHERE t1.Status = ''
AND t2.Status <> ''
AND t2.Status = 'Developed'
;

# Find the 2 rows of with null values ( Afghanistan and Albania)
SELECT Country,Year,Lifeexpectancy
FROM worldlifexpectancy
WHERE Lifeexpectancy = '';

# fill the values with the avg between the last year to next year 
SELECT t1.Country,t1.Year,t1.Lifeexpectancy,
       t2.Country,t2.Year,t2.Lifeexpectancy,
	   t3.Country,t3.Year,t3.Lifeexpectancy,
       round((t2.Lifeexpectancy + t3.Lifeexpectancy)/2,1)
FROM worldlifexpectancy t1
JOIN worldlifexpectancy t2 
     ON t1.Country = t2.Country 
     AND t1.Year = t2.Year - 1 
JOIN worldlifexpectancy t3
     ON t1.Country = t3.Country 
     AND t1.Year = t3.Year + 1
Where t1.Lifeexpectancy = '';

UPDATE worldlifexpectancy t1
JOIN worldlifexpectancy t2 
     ON t1.Country = t2.Country 
     AND t1.Year = t2.Year - 1 
JOIN worldlifexpectancy t3
     ON t1.Country = t3.Country 
     AND t1.Year = t3.Year + 1 
SET t1.Lifeexpectancy =   round((t2.Lifeexpectancy + t3.Lifeexpectancy)/2,1)
Where t1.Lifeexpectancy = '' ;


#3. Analysis and Insights

-- Ranking countries based on a composite score:
-- We consider multiple factors to determine the "best" countries:
-- 1. Life expectancy (40% weight): Higher life expectancy reflects better health systems and quality of life.
-- 2. GDP (30% weight): A higher GDP generally correlates with better infrastructure and opportunities.
-- 3. Schooling (20% weight): Education levels influence a country's development and living standards.
-- 4. Immunization rates (10% weight): Reflects the effectiveness of public health initiatives.

SELECT 
    Country,
    ROUND(AVG(Lifeexpectancy),1) AS AvgLifeExpectancy, -- Average life expectancy over all years
    ROUND(AVG(GDP),1) AS AvgGDP,                       -- Average GDP over all years
    ROUND(AVG(Schooling),1) AS AvgSchooling,           -- Average years of schooling over all years
    Round(AVG((Polio + Diphtheria)),1 / 2) AS AvgImmunizationRate, -- Average immunization rates for key diseases
    ROUND((AVG(Lifeexpectancy) * 0.4               -- Weighted composite score formula
     + AVG(GDP) * 0.3 
     + AVG(Schooling) * 0.2 
     + AVG((Polio + Diphtheria) / 2) * 0.1),1) AS CompositeScore
FROM worldlifexpectancy
GROUP BY Country
ORDER BY CompositeScore DESC; -- Countries with higher scores are considered better for living.

#Trends Over Time
#Global Trends in Life Expectancy
#This query evaluates the overall improvement in life expectancy across all countries over the years.

-- Analyzing global trends in life expectancy:
-- Objective: Determine whether global life expectancy has improved over time.
-- AVG(Lifeexpectancy) computes the average across all countries for each year.

SELECT 
    Year,                                -- Year of observation
    ROUND(AVG(Lifeexpectancy),1) AS GlobalAvgLifeExpectancy -- Average life expectancy for all countries
FROM worldlifexpectancy
GROUP BY Year                            -- Grouping by year to observe trends
ORDER BY Year;                           -- Chronological order to study progression


-- The best yea in life expectancy top 10 countries:

SELECT 
    Year,                                -- Year of observation
    Country,                              
    Round(AVG(Lifeexpectancy),1) AS AvgLifeExpectancy -- Regional average life expectancy
FROM worldlifexpectancy
GROUP BY Year, Country                    -- Group by both year and region
ORDER BY Year, AvgLifeExpectancy DESC   -- Chronological order, with highest life expectancy regions on top
LIMIT 10 ; 

#Insights on Health Investments
# This query explores whether higher health expenditures (percentage of GDP) correlate with better life expectancy outcomes.
-- Relationship between health expenditure and life expectancy:
-- Hypothesis: Countries that invest more in health (percentageexpenditure) tend to have higher life expectancy.

SELECT 
    Country,                             -- Country name
    AVG(percentageexpenditure) AS AvgHealthExpenditure, -- Average health expenditure as a percentage of GDP
    AVG(Lifeexpectancy) AS AvgLifeExpectancy -- Average life expectancy
FROM worldlifexpectancy
GROUP BY Country                        -- Analyze at the country level
ORDER BY AvgHealthExpenditure DESC;     -- Highlight countries with the highest health investment

#Highlighting Outliers

# Countries With the Most Improvement in Life Expectancy

# This query identifies countries that have significantly improved life expectancy over the years.

-- Identify countries with the largest life expectancy improvement:
-- Objective: Highlight success stories in healthcare and development.

SELECT 
    Country,                              -- Country name
    MAX(Lifeexpectancy) - MIN(Lifeexpectancy) AS LifeExpectancyChange -- Total change in life expectancy
FROM worldlifexpectancy
GROUP BY Country                         -- Group by country to calculate improvement per country
ORDER BY LifeExpectancyChange DESC;      -- Countries with the highest improvement come first



#Countries With Declining Life Expectancy
#This query finds countries where life expectancy has decreased, possibly due to conflict, poor health systems, or economic decline.
-- Identify countries with declining life expectancy:
-- Objective: Highlight areas of concern that may need policy interventions.

SELECT 
    Country,                              -- Country name
    MAX(Lifeexpectancy) - MIN(Lifeexpectancy) AS LifeExpectancyChange -- Negative values indicate a decline
FROM worldlifexpectancy
GROUP BY Country                         -- Group by country to calculate change
HAVING LifeExpectancyChange < 0;         -- Filter only countries with a decline in life expectancy
