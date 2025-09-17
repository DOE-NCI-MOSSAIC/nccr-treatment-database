-- DOCUMENTATION: See README.md
-- This file creates all staging files for Regimens. 

create temporary sequence RegimenID start 1;

create temporary table Regimens (
	RegimenID INTEGER,
	RegimenName VARCHAR
);

-- Regimen Staging Table 7 (SEER RX)
create temporary table unnested_seerrx_regimens as
select DISTINCT
	lower(unnest(s.drugs)) as "drugs",
	lower(s.name) as "regimen",
	lower(unnest(s.alternate_names)) as "alternate_names"
from 
	TREATMENT.SRC_SEER_RX_REGIMENS as s;


INSERT INTO Regimens
with ListRegimens as (
	select DISTINCT
		regimen,
	from 
		unnested_seerrx_regimens as s
) SELECT 
	nextval('RegimenID') as RegimenID,
	b.*
FROM 
	ListRegimens as b;
--467

INSERT INTO Regimens
WITH ListRegimens AS (
	select DISTINCT 
		alternate_names
	from 
		unnested_seerrx_regimens as s
	where alternate_names NOT IN (
		SELECT 
			RegimenName
		from 
			Regimens)
) select
	nextval('RegimenID') as RegimenID,
	b.*
FROM 
	ListRegimens as b;
--146

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		drugs 
	FROM 
		unnested_seerrx_regimens 
	WHERE 
		drugs NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--3


CREATE TEMPORARY TABLE source_7_preprocessing_regimens AS 
SELECT DISTINCT 
	r.RegimenID as "regimen_id",
	us.regimen as "regimen_name",
	us.alternate_names as "synonym_name",
	rr.RegimenID as "synonym_id",
	us.drugs as "anchor_drug",
	d.DrugID as "anchor_id",
	7 as source_id
FROM 
	unnested_seerrx_regimens as us
left join Regimens as r
	on us.regimen = r.RegimenName
left join Regimens as rr
	on us.alternate_names = rr.RegimenName
left join Drugs as d 
	on us.drugs = d.DrugName
where lower(us.alternate_names) != lower(us.regimen)
or alternate_names IS NULL;

update source_7_preprocessing_regimens
set synonym_name = 'none'
where synonym_name IS NULL;

update source_7_preprocessing_regimens
set synonym_id = 1000000
where synonym_id IS NULL;

create temporary sequence source_7_rowids_regimens start 1;

CREATE TEMPORARY TABLE source_7_regimens (
	source_7_rowids_regimens INTEGER,
	regimen_id INTEGER,
	regimen_name VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	anchor_drug VARCHAR,
	anchor_id	INTEGER,
	source_id INTEGER
);


INSERT into source_7_regimens
with x as (
	select DISTINCT 
		*
	from 
		source_7_preprocessing_regimens
	where synonym_id not in (
		SELECT 
			regimen_id 
		from source_7_preprocessing_regimens)
	UNION
	--SWAP
	SELECT DISTINCT
		synonym_id,
		synonym_name,
		regimen_name,
		regimen_id,
		anchor_drug,
		anchor_id,
		source_id
	FROM 
		source_7_preprocessing_regimens
	WHERE synonym_id in (
		SELECT 
			regimen_id 
		from source_7_preprocessing_regimens)
) select 
	nextval('source_7_rowids_regimens') as source_7_rowids_regimens,
	x.*
from x;	
--146

CREATE TEMPORARY TABLE source_7_circular_delete_regimen AS 
SELECT DISTINCT 
	f1.source_7_rowids_regimens,
	f1.regimen_name,
	f1.synonym_name,
	f1.source_id
FROM 
	source_7_regimens AS f1
JOIN 
	source_7_regimens AS f2
	ON
		f1.regimen_name = f2.synonym_name
	AND 
		f1.synonym_name = f2.regimen_name
	WHERE 
		f1.regimen_id > f1.synonym_id;
--0
	
delete from source_7_regimens
where source_7_rowids_regimens in (
	select 
		source_7_rowids_regimens
	from 
		source_7_circular_delete_regimen);	
--del 0

create temporary table source_7_swap_delete_regimens as
select DISTINCT 
	*
from 
	source_7_regimens
where
	regimen_id > synonym_id;
--0

delete from source_7_regimens
where source_7_rowids_regimens in (
	select 
		source_7_rowids_regimens
	from 
		source_7_swap_delete_regimens);
--del 0
	
insert into source_7_regimens	
select DISTINCT 
	source_7_rowids_regimens as 'source_7_rowids_regimens',
	synonym_id as 'regimen_id',
	synonym_name as 'regimen_name',
	regimen_name as 'synonym_name',
	regimen_id as 'synonym_id',
	anchor_drug as 'anchor_drug',
	anchor_id as 'anchor_id',
	source_id as 'source_id'
from 
	source_7_swap_delete_regimens;
--0

create temporary table source_7_chaining_regimen as
select DISTINCT  
	t1.source_7_rowids_regimens AS "first_rowid",
	t1.regimen_id as "first_anchor_id",
	t1.regimen_name AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.anchor_drug as "first_anchor_drug",
	t1.anchor_id as "first_anchor_ids",
	t2.source_7_rowids_regimens AS "second_rowid",
	t2.regimen_id as "second_anchor_id",
	t2.regimen_name as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.anchor_drug as "second_anchor_drug",
	t2.anchor_id as "second_anchor_id",
	t2.source_id as "second_source_id"
from 
	source_7_regimens as t1 
join 
	source_7_regimens as t2
	on 
		t1.synonym_name = t2.regimen_name
where
		t1.regimen_name != t2.synonym_name;	
--0

delete FROM source_7_regimens 
WHERE source_7_rowids_regimens IN (
	SELECT 
		second_rowid
	FROM 
		source_7_chaining_regimen);	
--del 0
	
INSERT INTO source_7_regimens
SELECT DISTINCT 
	second_rowid as "source_7_rowids_regimens",
	first_anchor_id as "regimen_id",
	first_anchor AS "regimen_name",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_anchor_drug as "anchor_drug",
	second_anchor_id as "anchor_id",
	second_source_id as "source_id"
FROM 
	source_7_chaining_regimen;
--0
	
create temporary table source_7_staging_regimens as
select DISTINCT 
	regimen_id,
	regimen_name,
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_7_regimens;		
--146

select * from source_7_staging_regimens;




-- Source 1 Staging File (HEMONC)
INSERT INTO Regimens
with ListRegimens as (
	select DISTINCT
		lower(concept_name)
	FROM
		TREATMENT.SRC_HEMONC_CONCEPT_STAGE 
	WHERE 
		domain_id = 'regimen'
	AND 
		invalid_reason IS NULL
	and concept_name NOT IN (
		SELECT 
			RegimenName
		from 
			Regimens)
) SELECT 
	nextval('RegimenID') as RegimenID,
	b.*
FROM 
	ListRegimens as b;
--7420

insert into Regimens
with ListRegimens as (
	select DISTINCT 
		lower(synonym_name) 
	FROM 
		TREATMENT.SRC_HEMONC_CONCEPT_SYNONYM_STAGE
	WHERE 
		invalid_reason IS NULL
	and synonym_name NOT IN (
		SELECT 
			RegimenName
		from 
			Regimens)
) SELECT 
	nextval('RegimenID') as RegimenID,
	b.*
FROM 
	ListRegimens as b;
--110553

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		component 
	FROM 
		TREATMENT.SRC_HEMONC_SIGS 
	WHERE 
		component NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--548


CREATE TEMPORARY TABLE source_1_prep_regimens AS 
WITH hcs AS (
		SELECT 
			lower(concept_name) AS "regimen",
			concept_code,
			domain_id
		FROM
			TREATMENT.SRC_HEMONC_CONCEPT_STAGE 
		WHERE 
			domain_id = 'regimen'
		AND 
			invalid_reason IS NULL),
	hcss AS (
		SELECT DISTINCT 
			lower(synonym_name) AS "regimen_synonym",
			synonym_concept_code
		FROM 
			TREATMENT.SRC_HEMONC_CONCEPT_SYNONYM_STAGE
		WHERE 
			invalid_reason IS NULL
) SELECT DISTINCT 
	--r.RegimenID as "regimen_id",
	lower(h.regimen) AS "regimen",
	lower(h.component) AS "anchor_drug",
	--d.DrugID as "anchor_id",
	lower(s.regimen_synonym) as "synonym_name",
	--rr.RegimenID as "synonym_id",
	1 as source_id
FROM 
	TREATMENT.SRC_HEMONC_SIGS as h
LEFT JOIN hcs AS c
	ON lower(h.regimen) = lower(c.regimen)
LEFT JOIN hcss AS s
	ON c.concept_code = s.synonym_concept_code
WHERE 
	lower(c.regimen) != lower(s.regimen_synonym)
and 
	lower(h.component_role) like ('primary systemic');


create temporary table source_1_preprocessing_regimens as 
select DISTINCT 
	r.RegimenID as "regimen_id",
	s.regimen as "regimen_name",
	s.synonym_name,
	rr.RegimenID as "synonym_id",
	s.anchor_drug,
	d.DrugID as "anchor_id",
	s.source_id
from source_1_prep_regimens as s
left join Regimens as r
	on regimen = r.RegimenName
left join Regimens as rr
	on synonym_name = rr.RegimenName
left join Drugs as d 
	on anchor_drug = d.DrugName;
--22410	

create temporary sequence source_1_rowids_regimens start 1;

CREATE TEMPORARY TABLE source_1_regimens (
	source_1_rowids_regimens INTEGER,
	regimen_id INTEGER,
	regimen_name VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	anchor_drug VARCHAR,
	anchor_id	INTEGER,
	source_id INTEGER
);


select * from source_1_preprocessing_regimens limit 1;

INSERT into source_1_regimens
with x as (
	select DISTINCT 
		*
	from 
		source_1_preprocessing_regimens
	where synonym_id not in (
		SELECT 
			regimen_id 
		from source_1_preprocessing_regimens)
	UNION
	--SWAP
	SELECT DISTINCT
		synonym_id,
		synonym_name,
		regimen_name,
		regimen_id,
		anchor_drug,
		anchor_id,
		source_id
	FROM 
		source_1_preprocessing_regimens
	WHERE synonym_id in (
		SELECT 
			regimen_id 
		from source_1_preprocessing_regimens)
) select 
	nextval('source_1_rowids_regimens') as source_1_rowids_regimens,
	x.*
from x;	
--22410

CREATE TEMPORARY TABLE source_1_circular_delete_regimen AS 
SELECT DISTINCT 
	f1.source_1_rowids_regimens,
	f1.regimen_name,
	f1.synonym_name,
	f1.source_id
FROM 
	source_1_regimens AS f1
JOIN 
	source_1_regimens AS f2
	ON
		f1.regimen_name = f2.synonym_name
	AND 
		f1.synonym_name = f2.regimen_name
	WHERE 
		f1.regimen_id > f1.synonym_id;
--27
	
delete from source_1_regimens
where source_1_rowids_regimens in (
	select 
		source_1_rowids_regimens
	from 
		source_1_circular_delete_regimen);	
--del 27

create temporary table source_1_swap_delete_regimens as
select DISTINCT 
	*
from 
	source_1_regimens
where
	regimen_id > synonym_id;
--6299

delete from source_1_regimens
where source_1_rowids_regimens in (
	select 
		source_1_rowids_regimens
	from 
		source_1_swap_delete_regimens);
--del 6299
	
insert into source_1_regimens	
select DISTINCT 
	source_1_rowids_regimens as 'source_1_rowids_regimens',
	synonym_id as 'regimen_id',
	synonym_name as 'regimen_name',
	regimen_name as 'synonym_name',
	regimen_id as 'synonym_id',
	anchor_drug as 'anchor_drug',
	anchor_id as 'anchor_id',
	source_id as 'source_id'
from 
	source_1_swap_delete_regimens;
--6299

create temporary table source_1_chaining_regimen as
select DISTINCT  
	t1.source_1_rowids_regimens AS "first_rowid",
	t1.regimen_id as "first_anchor_id",
	t1.regimen_name AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.anchor_drug as "first_anchor_drug",
	t1.anchor_id as "first_anchor_ids",
	t2.source_1_rowids_regimens AS "second_rowid",
	t2.regimen_id as "second_anchor_id",
	t2.regimen_name as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.anchor_drug as "second_anchor_drug",
	t2.anchor_id as "second_anchor_id",
	t2.source_id as "second_source_id"
from 
	source_1_regimens as t1 
join 
	source_1_regimens as t2
	on 
		t1.synonym_name = t2.regimen_name
where
		t1.regimen_name != t2.synonym_name;	
--161038

	
delete FROM source_1_regimens 
WHERE source_1_rowids_regimens IN (
	SELECT 
		second_rowid
	FROM 
		source_1_chaining_regimen);	
--del 12053
	
INSERT INTO source_1_regimens
SELECT DISTINCT 
	second_rowid as "source_1_rowids_regimens",
	first_anchor_id as "regimen_id",
	first_anchor AS "regimen_name",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_anchor_drug as "anchor_drug",
	second_anchor_id as "anchor_id",
	second_source_id as "source_id"
FROM 
	source_1_chaining_regimen;
--43859
	
create temporary table source_1_staging_regimens as
select DISTINCT 
	regimen_id,
	regimen_name,
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_1_regimens;		



-- This next section of code creates the final staging table for drugs
-- Create the shell table
create temporary sequence final_regimen_rowids start 1;


CREATE TEMPORARY TABLE Final_Regimen_Staging_Table (
	final_regimen_rowids INT,
	regimen_name VARCHAR,
	regimen_id INT,
	regimen_synonym VARCHAR,
	regimen_synonym_id INT,
	anchor_drug VARCHAR,
	anchor_id INT,
	source_id INT
);


INSERT INTO Final_Regimen_Staging_Table
with x as (
	SELECT DISTINCT 
		regimen_name,
		regimen_id,
		synonym_name,
		synonym_id,
		anchor_drug,
		anchor_id,
		source_id
	from 
		source_7_staging_regimens
) select 
	nextval('final_regimen_rowids') as final_regimen_rowids,
	x.*
from x;
--146

INSERT INTO Final_Regimen_Staging_Table
with x as (
	SELECT DISTINCT 
		regimen_name,
		regimen_id,
		synonym_name,
		synonym_id,
		anchor_drug,
		anchor_id,
		source_id
	from 
		source_1_staging_regimens
	WHERE 
		synonym_id not in (
			select 
				regimen_id
			from 
				source_1_staging_regimens)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_name,	
			synonym_id,
			regimen_name,
			regimen_id,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_1_preprocessing_regimens
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from source_1_preprocessing_regimens)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--26960

select * from Final_Regimen_Staging_Table;

create temporary table source_1_chaining_final as
select DISTINCT  
	t1.final_regimen_rowids AS "first_rowid",
	t1.regimen_id as "first_anchor_id",
	t1.regimen_name AS "first_anchor", 
	t1.regimen_synonym as "first_syn",
	t1.regimen_synonym_id as "first_syn_id",
	t1.source_id as "first_source_id",
	t1.anchor_drug as "first_anchor_drug",
	t1.anchor_id as "first_anchor_ids",
	t2.final_regimen_rowids AS "second_rowid",
	t2.regimen_id as "second_anchor_id",
	t2.regimen_name as "second_anchor",
	t2.regimen_synonym AS "second_syn", 
	t2.regimen_synonym_id as "second_syn_id",
	t2.anchor_drug as "second_anchor_drug",
	t2.anchor_id as "second_anchor_id",
	t2.source_id as "second_source_id"
from 
	Final_Regimen_Staging_Table as t1 
join 
	Final_Regimen_Staging_Table as t2
	on 
		t1.regimen_synonym = t2.regimen_name
where
		t1.regimen_name != t2.regimen_synonym;	
--99469

delete FROM Final_Regimen_Staging_Table 
WHERE final_regimen_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_1_chaining_final);	
--3369
	
INSERT INTO Final_Regimen_Staging_Table
SELECT DISTINCT 
	second_rowid as "final_regimen_rowids",
	first_anchor AS "regimen_name",
	first_anchor_id as "regimen_id",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_anchor_drug as "anchor_drug",
	second_anchor_id as "anchor_id",
	second_source_id as "source_id"
FROM 
	source_1_chaining_final;
--27444
--final number keeps changing
