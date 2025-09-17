
select * 
from treatment.SRC_AACT_INTERVENTIONS sai
where name like ('CHOP');

select * from TREATMENT.SRC_AACT_INTERVENTIONS_OTHER saio 
limit 10;


-- distinct will not work with the ids;
-- add additional qc checks on groubpy and agg functions for counts

CREATE TEMPORARY TABLE aact_filtering AS
SELECT DISTINCT 
	lower(a.name) as "anchor_drug",
	lower(o.name) as "synonym_name",
	6 as source_id
FROM 
	TREATMENT.SRC_AACT_INTERVENTIONS as a
JOIN 
	TREATMENT.SRC_AACT_INTERVENTIONS_OTHER as o
	on 
		a.id = o.intervention_id 
where 
	a.intervention_type like ('DRUG')
and 
	---self checking
	lower(a.name) != lower(o.name);


--select * 
--from aact_filtering
--where anchor_drug like ('vincristine');
--


select count(*) from aact_filtering;
--106028

create temporary sequence rowid start 1;

CREATE TEMPORARY TABLE aact_rowids (
	rowid INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	source_id INTEGER
);

INSERT into aact_rowids
with x as (
	select DISTINCT 
		*
	from 
		aact_filtering
) select 
	nextval('rowid') as rowid,
	x.*
from x;
--106028


create temporary table source_6_staging_drugs_cross as
select DISTINCT 
	f2.rowid,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
from 
	aact_rowids as f1
join 
 	aact_rowids as f2
on 
	f1.anchor_drug = f2.synonym_name
and 
	f1.synonym_name = f2.anchor_drug;


select count(*) from source_6_staging_drugs_cross;
--5340

--5340 found
delete from aact_rowids
where rowid in (
	select 
		rowid
	from 
		source_6_staging_drugs_cross);
--5340 deleted
	
create temporary table source_6_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	aact_rowids;

select count(*) from source_6_staging_drugs;

