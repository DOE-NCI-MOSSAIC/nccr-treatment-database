-- Source 2 Staging Table for CanMED

-- Grab generic names and brand names from the same file
CREATE TEMPORARY TABLE source_2_staging AS 
SELECT DISTINCT 
	c.generic_name as "anchor_drug",
	c.brand_name as "synonym_name",
	2 as source_id
FROM 
	treatment.canmed_ndc as c
	WHERE
		-- remove self referencing
		c.generic_name != c.brand_name; 
	
--INSERT INTO source_2_staging
--SELECT 
--	s.synonym_name,
--	s.anchor_drug,
--	s.source_id
--FROM 
--	source_2_staging AS s
--WHERE 
--	s.anchor_drug IN 
--	(SELECT DISTINCT s.synonym_name from source_2_staging);

SELECT DISTINCT COUNT(*)
FROM source_2_staging;

	

-- help here
--DELETE *
--	FROM 
--		source_2_staging
--	WHERE
--		anchor_drug IN 
--		(SELECT DISTINCT synonym_name from source_2_staging);