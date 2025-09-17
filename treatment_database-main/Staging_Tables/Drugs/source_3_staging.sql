--Source 3 Staging Table DrugBank

CREATE TEMPORARY TABLE source_3_staging AS
SELECT DISTINCT 
	d.common_name as "anchor_drug",
	d.synonyms as "synonym_name",
	3 as source_id
FROM 
	treatment.drugbank_vocab as d
	WHERE
		d.common_name != d.synonyms;
		
SELECT DISTINCT COUNT(*)
FROM source_3_staging;


--INSERT INTO source_3_staging
--SELECT 
--	s.synonym_name,
--	s.anchor_drug,
--	s.source_id
--FROM 
--	source_3_staging AS s
--WHERE 
--	s.anchor_drug IN 
--	(SELECT DISTINCT s.synonym_name from source_3_staging);
	
SELECT DISTINCT COUNT(*)
FROM source_3_staging;


-- help here
--DELETE *
--	FROM 
--		source_3_staging
--	WHERE
--		anchor_drug IN 
--		(SELECT DISTINCT synonym_name from source_3_staging);