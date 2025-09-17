-- This is table 1: anchor drug id  and anchor drug names

-- create auto index
CREATE TEMPORARY SEQUENCE anchor_drug_id START 1;

-- create shell table
CREATE TEMPORARY TABLE Anchor_Drugs (
	anchor_drug_id INTEGER PRIMARY KEY,
	anchor_drug_name VARCHAR
);

-- grab what we need from the staging table
INSERT INTO Anchor_Drugs
SELECT 
	nextval('anchor_drug_id') as anchor_drug_id,
	x.*
from 
	(select DISTINCT 
		f.anchor_drug as "anchor_drug_name"
		from 
			Final_Staging_Table as f) 
as x;


SELECT DISTINCT * from Anchor_Drugs as a;

