-- Table 9: Regimen ID and Regimen Souce

--create shell table
CREATE TEMPORARY TABLE Regimen_Source (
	regimen_id INT,
	source_id INT
);

-- insert from staging table & regimen name table
INSERT INTO Regimen_Source
SELECT 
	n.regimen_id,
	r.source_id
from 
	Regimen_Name as n
join 
	Final_Regimen_Staging_Table as r
	on r.regimen = n.regimen_name;

SELECT count(*) from Regimen_Source;

	