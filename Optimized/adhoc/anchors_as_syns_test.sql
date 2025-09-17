--CREATE TEMPORARY TABLE source_2_swaps as
CREATE TEMPORARY TABLE source_2_preprocessing AS 
SELECT DISTINCT 
	lower(c.generic_name) as "anchor_drug",
	lower(c.brand_name) as "synonym_name",
	2 as source_id
FROM 
	TREATMENT.canmed_ndc as c
	WHERE
		LOWER(c.generic_name) != LOWER(c.brand_name);
		
create temporary sequence source_2_rowids start 1;

CREATE TEMPORARY TABLE source_2 (
	source_2_rowids INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	source_id INTEGER
);

INSERT into source_2
with x as (
	select DISTINCT 
		*
	from 
		source_2_preprocessing
) select 
	nextval('source_2_rowids') as source_2_rowids,
	x.*
from x;	
	
CREATE TEMPORARY TABLE source_2_circular AS 
SELECT DISTINCT
	f2.source_2_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	source_2 AS f1
JOIN 
	source_2 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
		
delete from source_2
where source_2_rowids in (
	select 
		source_2_rowids
	from 
		source_2_circular);	

select DISTINCT 
	source_2_rowids,
	anchor_drug as 'synonym_name',
	synonym_name as 'anchor_drug',
	source_id
from source_2 
where synonym_name in (
	select DISTINCT 
		anchor_drug
	from source_2);	
	
delete from source_2
where source_2_rowids in (
	select 
		source_2_rowids
	from 
		source_2_swaps);	
	
insert into source_2	
select 
	source_2_rowids as 'source_2_rowids',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name',
	source_id as 'source_id'
from source_2_swaps;

create temporary table source_2_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	source_2;	
	

