-- This file creates a staging table for the HEMOC regimens dataset.

-- Here, we grab regimens, anchor drugs, and assign the source
CREATE TEMPORARY TABLE source_1_regimens AS 
SELECT DISTINCT 
	h.regimen,
	h.component as "anchor_drug",
	1 as source_id
FROM 
	treatment.hemonc_sigs as h;

select DISTINCT count(*) from source_1_regimens;


-- here, we grab regimens and their nicknames
CREATE temporary table source_1_regimens_syns AS
select DISTINCT 
	h.concept_name as "regimen",
	s.synonym_name as "regimen_synonym"
from 
	treatment.hemonc_concept_stage as h
join 
	treatment.hemonc_concept_synonym_stage as s 
	on h.concept_code = s.synonym_concept_code 
where 
	h.domain_id LIKE ('regimen')
	and 
	h.concept_name != s.synonym_name; 

select DISTINCT count(*) from source_1_regimens_syns;

	
-- We combine the other tables created above to get the hemoc staging table
create temporary table source_1_staging_regimens as
SELECT DISTINCT 
	r.regimen,
	r.anchor_drug,
	r.source_id,
	s.regimen_synonym
from 
	source_1_regimens as r
left join 
	source_1_regimens_syns as s
	on r.regimen = s.regimen;
	
SELECT * from source_1_staging_regimens;


