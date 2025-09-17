-- Create the regimen staging table for SEER RXs

-- unnest the drugs and synonmys
CREATE TEMPORARY TABLE source_7_staging_regimens AS 
SELECT DISTINCT 
	UNNEST(s.drugs) as "anchor_drug",
	UNNEST(s.alternate_names) as "regimen_synonyms",
	s.name as "regimen",
	7 as source_id
FROM 
	treatment.seer_rx_regimens as s;
