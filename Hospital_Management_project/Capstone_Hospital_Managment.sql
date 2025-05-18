CREATE DATABASE Hospital_Managment
USE Hospital_Managment
SELECT * FROM encounters
SELECT * FROM organizations
SELECT * FROM patients
SELECT * FROM payers
SELECT * FROM procedures

SELECT COUNT(E.PATIENT) AS No_of_patients_without_insurance FROM encounters E
LEFT JOIN payers P
ON E.PAYER=P.Id
WHERE P.NAME='NO_INSURANCE'
GROUP BY E.PATIENT

-- Determine which ReasonCodes lead to the highest financial risk based on the total uncovered cost (difference between 
-- total claim cost and payer coverage). Analyze this by combining patient demographics and encounter outcomes.

SELECT REASONCODE,REASONDESCRIPTION,
	   COUNT(REASONCODE) AS Counts,
	   ROUND(SUM(TOTAL_CLAIM_COST-PAYER_COVERAGE),2) AS Total_Uncovered_Cost,
	   ROUND(AVG(TOTAL_CLAIM_COST-PAYER_COVERAGE),2) AS Average_Uncovered_Cost 
	   FROM encounters	   
GROUP BY REASONCODE,REASONDESCRIPTION
ORDER BY 4 DESC;

-- Identify patients who had more than 3 encounters in a year where each encounter had a total claim cost above a certain 
-- threshold (e.g., $10,000). The query should return the patient details, number of encounters, and the total cost for 
-- those encounters.

SELECT P.ID,CONCAT(P.PREFIX,' ',TRIM('0123456789' FROM P.First),' ',TRIM('0123456789' FROM P.Last)) AS NAME,
E.COUNT,E.Total_Claim,E.YEAR FROM patients P
RIGHT JOIN (SELECT PATIENT,COUNT(ID) AS COUNT,YEAR(START) AS YEAR,SUM(TOTAL_CLAIM_COST) AS Total_Claim FROM encounters
WHERE TOTAL_CLAIM_COST>10000
GROUP BY PATIENT,YEAR(START) ) E
ON P.Id=E.PATIENT
WHERE E.COUNT>3 
ORDER BY 2

-- Analyze the top 3 most frequent diagnosis codes (ReasonCodes) and the associated patient demographic data to understand which groups are 
-- most affected by high-cost encounters.

SELECT TOP 3 ReasonCode,REASONDESCRIPTION,COUNT(ID) AS PATIENT_COUNT FROM encounters
WHERE REASONCODE IS NOT NULL
GROUP BY REASONCODE,REASONDESCRIPTION
ORDER BY 3 DESC

SELECT * FROM patients P
RIGHT JOIN (SELECT Patient,ReasonCode,REASONDESCRIPTION,ID FROM encounters) E
ON P.Id=E.PATIENT
WHERE E.REASONCODE IN (SELECT TOP 3 REASONCODE FROM encounters 
WHERE REASONCODE IS NOT NULL
GROUP BY REASONCODE
ORDER BY COUNT(ID) DESC)

-- Analyze payer contributions for the base cost of procedures and identify any gaps between total claim cost and payer coverage.
SELECT NAME,E.COUNT,ROUND(E.COVERED_COST,2) AS COVERED_COST,
ROUND(E.CLAIMED_COST,2) AS CLAIMED_COST,
ROUND(E.CLAIMED_COST-E.COVERED_COST,2) AS UNCOVERED_COST,
ROUND((E.COVERED_COST/E.CLAIMED_COST)*100,2) AS PERCENT_COVERED FROM payers
INNER JOIN (SELECT PAYER,COUNT(ID) AS COUNT ,SUM(PAYER_COVERAGE) AS COVERED_COST,SUM(TOTAL_CLAIM_COST) AS CLAIMED_COST 
FROM encounters
GROUP BY PAYER) E
ON payers.Id=E.PAYER
ORDER BY 6 DESC

-- Find patients who had multiple procedures across different encounters with the same ReasonCode.
SELECT CONCAT(PREFIX,' ',TRIM('0123456789' FROM FIRST),' ',TRIM('0123456789' FROM LAST)) AS FULL_NAME,
E.REASONCODE,E.REASONDESCRIPTION,E.No_of_Procedure FROM patients P
RIGHT JOIN (SELECT PATIENT,COUNT(ID) AS No_of_Procedure,REASONCODE,REASONDESCRIPTION FROM encounters
GROUP BY PATIENT,REASONCODE,REASONDESCRIPTION) E
ON P.Id=E.PATIENT
WHERE E.REASONCODE IS NOT NULL
ORDER BY 4 DESC 

-- Calculate the average encounter duration for each class (EncounterClass) per organization, identifying any encounters that exceed 24 hours.
SELECT ENCOUNTERCLASS,O.NAME,
AVG(DATEDIFF(MINUTE,CAST(START AS DATETIME),CAST(STOP AS DATETIME))) AS MINUTES_TAKEN_FOR_PROCEDURE
FROM encounters E
LEFT JOIN organizations O
ON E.ORGANIZATION=O.Id
GROUP BY E.ENCOUNTERCLASS,O.NAME

SELECT ID,DATEDIFF(HOUR,CAST(START AS DATETIME),CAST(STOP AS DATETIME)) AS HOURS_TAKEN,ENCOUNTERCLASS,
DESCRIPTION,BASE_ENCOUNTER_COST,TOTAL_CLAIM_COST,PAYER_COVERAGE,REASONDESCRIPTION FROM encounters
WHERE DATEDIFF(HOUR,CAST(START AS DATETIME),CAST(STOP AS DATETIME))>24


-- EXTRA WORK
-- Function to calculate the total claim cost,base encounter cost and number of encounter for the given matching name phrase(multiple for people having same name).


GO
CREATE FUNCTION fn_patients_name(@name VARCHAR(100))
RETURNS TABLE
AS 
RETURN
(
	SELECT 
		P.FULL_NAME,
		COUNT(E.Id) AS ALL_ENCOUNTERS,
		SUM(E.TOTAL_CLAIM_COST) AS TOTAL_CLAIM,
		SUM(E.BASE_ENCOUNTER_COST) AS BASE_ENCOUNTER 
	FROM encounters E
	INNER JOIN (
		SELECT 
			ID, 
			CONCAT(PREFIX, ' ', 
			TRIM('0123456789' FROM FIRST), ' ',
			TRIM('0123456789' FROM LAST)) AS FULL_NAME  
		FROM patients
		WHERE COALESCE(FIRST, '') LIKE CONCAT('%', @name, '%') 
		OR COALESCE(LAST, '') LIKE CONCAT('%', @name, '%')
	) P ON E.PATIENT = P.Id
	GROUP BY P.FULL_NAME
);
GO

SELECT * FROM DBO.fn_patients_name('Nicolas')
SELECT * FROM DBO.fn_patients_name('Jay')

-- To show encounters that occured in a particular date along with important information involved
GO
 CREATE FUNCTION fn_Get_Encounter(@date DATE)
 RETURNS TABLE 
 AS 
 RETURN
 (
	SELECT E.ID,P.NAME_OF_PATIENT,REASONDESCRIPTION,TOTAL_CLAIM_COST,BASE_ENCOUNTER_COST,PAYER_COVERAGE FROM encounters E
	FULL JOIN (SELECT  ID,
			CONCAT(PREFIX, ' ', 
			TRIM('0123456789' FROM FIRST), ' ',
			TRIM('0123456789' FROM LAST)) AS NAME_OF_PATIENT  
		FROM patients ) P
	ON E.PATIENT=P.Id
	WHERE DATEPART(YEAR,E.START) = DATEPART(YEAR,@date) AND DATEPART(MONTH,E.START) = DATEPART(MONTH,@date) AND DATEPART(DAY,E.START) = DATEPART(DAY,@date)
	)
GO

SELECT * FROM DBO.fn_Get_Encounter('2011-02-02')


 