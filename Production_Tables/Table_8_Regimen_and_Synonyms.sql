-- code for table 8: regimen and regimen synonyms

-- create auto indexing
CREATE TEMPORARY SEQUENCE regimen_synonym_id START 1;

-- create shell table
CREATE TEMPORARY TABLE Regimens_And_Synonyms (
	regimen_synonym_id INTEGER PRIMARY KEY,
	regimen_synonym_name VARCHAR,
	source_id INT,
	regimen_id INT
);

-- insert from staging table
INSERT INTO Regimens_And_Synonyms
--create temporary table dropping as
SELECT 
	nextval('regimen_synonym_id') as regimen_synonym_id,
	x.*
from 
	(select DISTINCT 
		r.regimen_synonym_name,
		r.source_id,
		s.regimen_id,
		from Regimen_Name as s
		inner join Final_Regimen_Staging_Table as r 
			on r.regimen = s.regimen_name)
		--where r.regimen_synonym_name NOT LIKE ('%[%]%')) 
as x;
	
SELECT count(*) from Regimens_And_Synonyms;


