-- Create table 3 from our regimen staging table

-- create auto indexing
CREATE TEMPORARY SEQUENCE condition_id START 1;

--create shell table
CREATE TEMPORARY TABLE Conditions_And_Regimens (
	condition_id INT,
	condition_name VARCHAR,
	regimen_id INT,
	source_id INT
);

-- grab what we need from the staging table
-- this will only be a hemoc table
--INSERT INTO Conditions_And_Regimens
create temporary table indexs as
SELECT 
	nextval('condition_id') as condition_id,
	x.*
from 
	(select DISTINCT 
		h."condition",
		--r.regimen_id,
		1 as source_id
	FROM
--		Regimen_Sources AS r
--	JOIN 
		treatment.hemonc_pointer AS h)
--		ON h.regimen = r.regimen_name) 
as x;
	
--SELECT * FROM indexs;

INSERT INTO Conditions_And_Regimens
SELECT 
	i.condition_id,
	i."condition",
	r.regimen_id,
	i.source_id
FROM indexs AS i
JOIN treatment.hemonc_pointer AS h 
	ON h."condition" = i."condition"
JOIN Regimen_Name AS r 
	ON r.regimen_name = h.regimen
	WHERE i.source_id LIKE ('1');


SELECT * from Conditions_And_Regimens;



