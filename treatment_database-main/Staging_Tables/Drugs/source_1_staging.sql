-- Source 1 Staging Table is the staging table for HEMOC Data

-- Here, we get the anchor drug names from two hemoc files and the synonym names from a third file
CREATE TEMPORARY TABLE source_1_staging AS 
SELECT DISTINCT 
	h.component as "anchor_drug",
--	c.concept_name, this is same as component
	s.synonym_name as "synonym_name",
	1 as source_id,
--	c.concept_code, this is a unique code for each drug
--	s.synonym_concept_code many to one match to concept code
FROM 
	treatment.hemonc_sigs as h
	--we join here because the c file contains numeric match to file s
	LEFT JOIN treatment.hemonc_concept_stage as c
		ON h.component = c.concept_name
	-- join the drugs to their syns via codes
	LEFT JOIN treatment.hemonc_concept_synonym_stage AS s 
		on c.concept_code = s.synonym_concept_code
	WHERE
		-- remove self references
		h.component != s.synonym_name;


-- Here, we flip anchors and drugs to make sure we don't have inverse information in our table
--INSERT INTO source_1_staging
--SELECT 
--	s.synonym_name,
--	s.anchor_drug,
--	s.source_id
--FROM 
--	source_1_staging AS s
--WHERE 
--	s.anchor_drug IN 
--	(SELECT DISTINCT s.synonym_name from source_1_staging);

-- check the count
SELECT DISTINCT COUNT(*)
FROM source_1_staging;
	
-- use this code block if we find inverse information above
--DELETE 
--	s.synonym_name,
--	s.anchor_drug,
--	s.source_id
--	FROM 
--		source_1_staging as s
--	WHERE
--		anchor_drug IN 
--		(SELECT DISTINCT s.synonym_name from source_1_staging);
	