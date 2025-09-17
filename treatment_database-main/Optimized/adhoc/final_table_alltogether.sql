CREATE TEMPORARY TABLE source_1_preprocessing AS 
WITH hcs AS (
		SELECT 
			concept_name,
			concept_code,
			domain_id
		FROM
			TREATMENT.SRC_HEMONC_CONCEPT_STAGE 
		WHERE
			invalid_reason IS NULL
		AND 
			domain_id = 'drug'),
	hcss AS (
		SELECT 
			synonym_name,
			synonym_concept_code
		FROM 
			TREATMENT.SRC_HEMONC_CONCEPT_SYNONYM_STAGE
		WHERE 
			invalid_reason IS NULL)
SELECT DISTINCT 
	lower(h.component) as "anchor_drug",
	lower(s.synonym_name) as "synonym_name",
	1 as source_id,
FROM 
	TREATMENT.SRC_HEMONC_SIGS as h
	LEFT JOIN hcs as c
		ON lower(h.component) = lower(c.concept_name)
	LEFT JOIN hcss AS s 
		on c.concept_code = s.synonym_concept_code
	WHERE
		lower(h.component) != lower(s.synonym_name);
	
create temporary sequence source_1_rowids start 1;

CREATE TEMPORARY TABLE source_1 (
	source_1_rowids INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	source_id INTEGER
);

-- condence this

INSERT into source_1
with x as (
	select DISTINCT 
		*
	from 
		source_1_preprocessing
) select 
	nextval('source_1_rowids') as source_1_rowids,
	x.*
from x;	
	
CREATE TEMPORARY TABLE source_1_circular AS 
SELECT DISTINCT
	f2.source_1_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	source_1 AS f1
JOIN 
	source_1 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
		
delete from source_1
where source_1_rowids in (
	select 
		source_1_rowids
	from 
		source_1_circular);	
	
create temporary table source_1_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	source_1;	
	





			
-- Source 2 Staging Table -- CanMed
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
	
--CREATE TEMPORARY TABLE source_2_circular AS 
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
	
create temporary table source_2_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	source_2;	


-- IMPLEMENT SWAPPING HERE
-- PICK THE ANCHOR BASED ON A LOWER ID



------------------------------------------------
create temporary sequence final_rowids start 1;

CREATE TEMPORARY TABLE Final_Drug_Staging_Table (
	final_rowids int,
	source_id INT,
	anchor_drug VARCHAR,
	synonym_name VARCHAR
);

-- Insert HemOnc
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT
		s1.source_id,
		s1.anchor_drug,
		s1.synonym_name
	FROM	
		source_1_staging_drugs as s1)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;

select count(*) from Final_Drug_Staging_Table;
--1577

select * from Final_Drug_Staging_Table limit 5;


create temporary table anchors as
select DISTINCT 
	anchor_drug
from Final_Drug_Staging_Table;

select count(*) from anchors;
--382


INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		s2.source_id,
		s2.anchor_drug,
		s2.synonym_name
	FROM	
		source_2_staging_drugs as s2)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;

select count(*) from Final_Drug_Staging_Table;
--2110

-- Use rowids & delete from 
-- 25 found here
create temporary table source_2_swaps as
select DISTINCT 
	f2.final_rowids,
	f2.anchor_drug as 'synonym_name',
	f2.synonym_name as 'anchor_drug',
	f2.source_id
from Final_Drug_Staging_Table as f2
where f2.synonym_name in (
	select DISTINCT 
		anchor_drug
	from anchors);

select * from source_2_swaps;

-- add canmed back to anchor table


--25 deleted
delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_2_swaps);
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_2_swaps;

	
select * from Final_Drug_Staging_Table;
--2110

----Check the circular references on final table
--SELECT DISTINCT
--	f2.final_rowids,
--	f2.anchor_drug,
--	f2.synonym_name,
--	f2.source_id
--FROM 
--	Final_Drug_Staging_Table AS f1
--JOIN 
--	Final_Drug_Staging_Table AS f2
--	ON
--		f1.anchor_drug = f2.synonym_name;



		
CREATE TEMPORARY TABLE chaining as		
with 
	table1 AS (
		SELECT DISTINCT 
			final_rowids,
			anchor_drug, --AS 'first_anchor',
			synonym_name, --AS 'first_syn',
			source_id
		FROM 
			Final_Drug_Staging_Table),
 	table2 AS (
		SELECT DISTINCT
			final_rowids,
			anchor_drug, --AS 'second_anchor',
			synonym_name, --AS 'second_syn'
			source_id
		FROM 
			Final_Drug_Staging_Table) 	
select DISTINCT 
	t1.final_rowids AS "first_rowid",
	t1.source_id AS "first_source",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t2.final_rowids AS "second_rowid",
	t2.source_id AS "second_source",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn" -- as "second_syn",
from 
	table1 as t1 
join 
	table2 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;


	
SELECT * FROM chaining LIMIT 5;

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM chaining
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;

--SELECT * from Final_Drug_Staging_Table
--where anchor_drug = 'mesna'
--or synonym_name = 'mesna';
----2194

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM chaining)
delete FROM Final_Drug_Staging_Table 
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);

SELECT * FROM Final_Drug_Staging_Table;	

----check for swaps	
select DISTINCT 
	final_rowids,
	anchor_drug as 'synonym_name',
	synonym_name as 'anchor_drug',
	source_id
from Final_Drug_Staging_Table 
where synonym_name in (
	select DISTINCT 
		anchor_drug
	from anchors);

				
-- Check for circular 
select *
from Final_Drug_Staging_Table
where anchor_drug like ('mesna injection') 
or synonym_name like ('mesna injection');

select 
	*
from Final_Drug_Staging_Table
where synonym_name in (
		select
			anchor_drug
		from 
			Final_Drug_Staging_Table);
		
select 
	*
from Final_Drug_Staging_Table
where anchor_drug in (
		select
			synonym_name
		from 
			Final_Drug_Staging_Table);

with 
	table1 AS (
		SELECT DISTINCT 
			--source_2_rowids,
			anchor_drug, --AS 'first_anchor',
			synonym_name, --AS 'first_syn',
			source_id
		FROM 
			source_2_staging_drugs),
 	table2 AS (
		SELECT DISTINCT
			--source_2_rowids,
			anchor_drug, --AS 'second_anchor',
			synonym_name, --AS 'second_syn'
			source_id
		FROM 
			source_2_staging_drugs) 	
select DISTINCT 
	--t1.source_2_rowids AS "first_rowid",
	t1.source_id AS "first_source",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	--t2.source_2_rowids AS "second_rowid",
	t2.source_id AS "second_source",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn" -- as "second_syn",
from 
	table1 as t1 
join 
	table2 as t2
	on 
		t1.synonym_name = t2.anchor_drug;

	
where
		t1.anchor_drug = t2.synonym_name;


			