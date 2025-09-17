-- Source 5 Staging Table for NCI

-- Once this is in final production table, we need to make the semantic_types from Austin
-- as a Table. We reuse these for RX Norm.


-- we first need to expland the columns to make joins easier below
CREATE TEMPORARY VIEW exploded_nci AS
SELECT 
	n.preferred_name,
	UNNEST(n.synonyms_and_abbreviations) as exploded_syns,
	UNNEST(n.semantic_type) as exploded_semantic
FROM treatment.nci_thesaurus AS n;

CREATE TEMPORARY TABLE source_5_staging as 
SELECT DISTINCT 
	n.preferred_name as "anchor_drug",
	e.exploded_syns as "synonym_name",
	5 as source_id
FROM 
	treatment.nci_thesaurus as n
LEFT JOIN 
	exploded_nci as e
	ON
	e.preferred_name = n.preferred_name
WHERE
	-- self reference check; don't include them
		e.exploded_syns != n.preferred_name
	AND 
		-- add all the exclusions from Austin
		exploded_semantic LIKE ('Enzyme')
	OR 
		exploded_semantic LIKE ('Antibiotics')
	OR 
		exploded_semantic LIKE ('Hazardous or Poisonous Substance')
	OR 
		exploded_semantic LIKE ('Amino Acids, Peptides, and Proteins')
	OR 
		exploded_semantic LIKE ('Immunologic Factor')
	OR 
		exploded_semantic LIKE ('Inorganic Chemical')
	OR 
		exploded_semantic LIKE ('Nucleic Acid, Nucleoside, or Nucleotide')
	OR 
		exploded_semantic LIKE ('Organic Chemical')
	OR 
		exploded_semantic LIKE ('Pharmacologic Substance'); 
	
SELECT DISTINCT COUNT(*)
FROM source_5_staging;
	
		
--INSERT INTO source_5_staging
--SELECT 
--	s.synonym_name,
--	s.anchor_drug,
--	s.source_id
--FROM 
--	source_5_staging AS s
--WHERE 
--	s.anchor_drug IN 
--	(SELECT DISTINCT s.synonym_name from source_5_staging);
--
--SELECT DISTINCT COUNT(*)
--FROM source_5_staging;
	
	
--DELETE *
--	FROM 
--		source_5_staging
--	WHERE
--		anchor_drug IN 
--		(SELECT DISTINCT synonym_name from source_1_staging);