-- code for table 7: regimen name and id

-- create auto index
CREATE TEMPORARY SEQUENCE regimen_id START 1;

-- create shell table
CREATE TEMPORARY TABLE Regimen_Name (
	regimen_id INTEGER PRIMARY KEY,
	regimen_name VARCHAR
	--source_id INT
);

-- insert from staging table
INSERT INTO Regimen_Name
SELECT 
	nextval('regimen_id') as regimen_id,
	x.*
from 
	(select DISTINCT 
		r.regimen as "regimen_name"
		--r.source_id
		from 
			Final_Regimen_Staging_Table as r) 
as x;
	
		
SELECT count(*) from Regimen_Name ;