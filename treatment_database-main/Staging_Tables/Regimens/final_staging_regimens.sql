-- create the final regimen staging table

-- shell table
CREATE TEMPORARY TABLE Final_Regimen_Staging_Table (
	source_id INT,
	regimen VARCHAR,
	regimen_synonym_name VARCHAR,
	anchor_drug VARCHAR
);

--insert hemoc
INSERT INTO Final_Regimen_Staging_Table
SELECT 
	s1.source_id,
	s1.regimen,
	s1.regimen_synonym as 'regimen_synonym_name',
	s1.anchor_drug
FROM	
	source_1_staging_regimens as s1;


SELECT DISTINCT *
FROM Final_Regimen_Staging_Table;

-- insert cog
-- cog doesn't include drugs in their files, i assign NULL to keep table format and avoid joins later down in processing
INSERT INTO Final_Regimen_Staging_Table
SELECT 
	s6.source_id,
	s6.protocol as "regimen",
	s6.regimen_synonyms as 'regimen_synonym_name',
	NULL as anchor_drug
FROM	
	source_6_staging_regimens as s6
WHERE 
	NOT EXISTS (
	SELECT fst.regimen
	FROM Final_Regimen_Staging_Table as fst
	WHERE s6.protocol = fst.regimen_synonym_name);


SELECT DISTINCT COUNT(*)
FROM Final_Regimen_Staging_Table;

INSERT INTO Final_Regimen_Staging_Table
SELECT 
	s7.source_id,
	s7.regimen,
	s7.regimen_synonyms as 'regimen_synonym_name',
	s7.anchor_drug
FROM	
source_7_staging_regimens as s7
WHERE 
	NOT EXISTS (
	SELECT fst.regimen
	FROM Final_Regimen_Staging_Table as fst
	WHERE s7.regimen = fst.regimen_synonym_name);


SELECT DISTINCT COUNT(*)
FROM Final_Regimen_Staging_Table;
