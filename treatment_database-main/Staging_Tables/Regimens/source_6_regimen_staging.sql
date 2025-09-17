-- here we create a staging table for the COG clinical trials dataset

-- unnest the synonyms
CREATE TEMPORARY TABLE source_6_staging_regimens AS 
SELECT DISTINCT 
	c.protocol,
	UNNEST(c.othernames) as "regimen_synonyms",
	6 as source_id
FROM 
	treatment.cog_protocols as c;

