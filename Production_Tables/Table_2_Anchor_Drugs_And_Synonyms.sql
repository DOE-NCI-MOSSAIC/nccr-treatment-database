-- This is the Code Base for the Anchor Drug & Synonyms Table.

-- create auto index
CREATE TEMPORARY SEQUENCE synonym_id START 1;

-- create shell table
CREATE TEMPORARY TABLE Anchor_Drugs_And_Synonyms (
	synonym_id INTEGER PRIMARY KEY,
	anchor_drug_id INT,
	synonym_name VARCHAR,
	source_id INT 
);

--grab what we need from the anchor drug table and staging table
INSERT INTO Anchor_Drugs_And_Synonyms
SELECT DISTINCT 
	nextval('synonym_id') as synonym_id,
	x.*
from 
	(select DISTINCT 
		a.anchor_drug_id,
		f.synonym_name,
		f.source_id
		from 
			Anchor_Drugs as a
		JOIN 
			Final_Staging_Table as f
			ON f.anchor_drug = a.anchor_drug_name) 
as x;
	
--SELECT * from Final_Staging_Table;


SELECT count(*)
FROM Anchor_Drugs_And_Synonyms;


