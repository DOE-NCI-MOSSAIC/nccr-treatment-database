-- DOCUMENTATION: See README.md
-- This file creates all staging files for Drugs. 
CREATE TEMPORARY SEQUENCE DrugID start 1;

--Drug shell table; This will list all unique drugs in each
--data source with a unique key
CREATE TEMPORARY TABLE DRUGS (
	DrugID INTEGER,
	DrugName VARCHAR
);

INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(c.concept_name) as drug
	FROM 
		treatment.SRC_HEMONC_CONCEPT_STAGE c
	WHERE
			invalid_reason IS NULL
		AND 
			domain_id = 'drug'
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--5788 from HemOnc

--Second, we insert the synonyms in the Drug Table in order where 
-- we have not already added that drug to the table as an anchor
INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(csn.synonym_name) 
	FROM 
		treatment.SRC_HEMONC_CONCEPT_SYNONYM_STAGE csn 
	WHERE 
			invalid_reason IS NULL
	and 
		lower(csn.synonym_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--1044783

-- Source 1 Staging Table -- HEMONC Data
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
			invalid_reason IS NULL
) SELECT DISTINCT 
	d.DrugID as "anchor_id",
	lower(h.concept_name) as "anchor_drug",
	lower(s.synonym_name) as "synonym_name",
	dd.DrugID as "synonym_id",
	1 as source_id,
FROM 
	TREATMENT.SRC_HEMONC_CONCEPT_STAGE as h
LEFT JOIN hcs as c
	ON lower(h.concept_name) = lower(c.concept_name)
LEFT JOIN hcss AS s 
	on c.concept_code = s.synonym_concept_code
left JOIN Drugs as d
	ON lower(h.concept_name) = d.DrugName
left JOIN Drugs as dd
	ON lower(s.synonym_name) = dd.DrugName
WHERE
		--self references
	lower(h.concept_name) != lower(s.synonym_name);
--2111
	
create temporary sequence source_1_rowids start 1;

CREATE TEMPORARY TABLE source_1 (
	source_1_rowids INTEGER,
	anchor_id	INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	source_id INTEGER
);

INSERT into source_1
with x as (
	select DISTINCT 
		*
	from 
		source_1_preprocessing
	where synonym_id not in (
		SELECT 
			anchor_id 
		from source_1_preprocessing)
	UNION
	--SWAP
	SELECT DISTINCT
		synonym_id,
		synonym_name,
		anchor_drug,
		anchor_id,
		source_id
	FROM source_1_preprocessing
	WHERE synonym_id in (
		SELECT 
			anchor_id 
		from source_1_preprocessing)
) select 
	nextval('source_1_rowids') as source_1_rowids,
	x.*
from x;	
--2111

CREATE TEMPORARY TABLE source_1_circular_delete AS 
SELECT DISTINCT 
	f1.source_1_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_1 AS f1
JOIN 
	source_1 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--1
	
delete from source_1
where source_1_rowids in (
	select 
		source_1_rowids
	from 
		source_1_circular_delete);	
--del 1

create temporary table source_1_swap_delete as
select DISTINCT 
	*
from 
	source_1
where
	anchor_id > synonym_id;
--0

delete from source_1
where source_1_rowids in (
	select 
		source_1_rowids
	from 
		source_1_swap_delete);
--del 0
	
insert into source_1	
select DISTINCT 
	source_1_rowids as 'source_1_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from source_1_swap_delete;
--0
	
	
create temporary table source_1_chaining as
select DISTINCT  
	t1.source_1_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_1_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_1 as t1 
join 
	source_1 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--0

delete FROM source_1 
WHERE source_1_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_1_chaining);	
--del 0

INSERT INTO source_1
SELECT DISTINCT 
	second_rowid as "source_1_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_1_chaining;
--0
	
create temporary table source_1_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_1;	
--2110




			
-- Source 2 Staging Table -- CanMed
INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(c.generic_name) as drug
	FROM 
		treatment.canmed_ndc c
	where 
		lower(c.generic_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--122

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(cn.brand_name) 
	FROM 
		treatment.canmed_ndc cn 
	where 
		lower(cn.brand_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--89

CREATE TEMPORARY TABLE source_2_preprocessing AS 
SELECT DISTINCT 
	d.DrugID as "anchor_id",
	lower(c.generic_name) as "anchor_drug",
	lower(c.brand_name) as "synonym_name",
	dd.DrugID as "synonym_id",
	2 as source_id
FROM 
	TREATMENT.canmed_ndc as c
left JOIN Drugs as d
	ON lower(c.generic_name) = d.DrugName
left JOIN Drugs as dd
	ON lower(c.brand_name) = dd.DrugName
WHERE
	--self references
	LOWER(c.generic_name) != LOWER(c.brand_name);
--549
	
create temporary sequence source_2_rowids start 1;

CREATE TEMPORARY TABLE source_2 (
	source_2_rowids INTEGER,
	anchor_id	INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id	INTEGER,
	source_id INTEGER
);	

INSERT into source_2
with x as (
		select DISTINCT 
			*
		from 
			source_2_preprocessing
		where synonym_id not in (
			SELECT 
				anchor_id 
			from 
				source_2_preprocessing)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_id,
			synonym_name,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_2_preprocessing
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from 
				source_2_preprocessing)
) select  
	nextval('source_2_rowids') as source_2_rowids,
	x.*
from x;	
--549

CREATE TEMPORARY TABLE source_2_circular_delete AS 
SELECT DISTINCT 
	f1.source_2_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_2 AS f1
JOIN 
	source_2 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--8
	
delete from source_2
where source_2_rowids in (
	select 
		source_2_rowids
	from 
		source_2_circular_delete);
--del8

create temporary table source_2_swap_delete as
select DISTINCT 
	*
from 
	source_2
where
	anchor_id > synonym_id;
--137
			
delete from source_2
where source_2_rowids in (
	select 
		source_2_rowids
	from 
		source_2_swap_delete);
--del 137

insert into source_2	
select DISTINCT 
	source_2_rowids as 'source_2_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from 
	source_2_swap_delete;
--137

create temporary table source_2_chaining as
select DISTINCT  
	t1.source_2_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_2_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_2 as t1 
join 
	source_2 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--65


delete FROM source_2 
WHERE source_2_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_2_chaining);	
--37
	
INSERT INTO source_2
SELECT DISTINCT 
	second_rowid as "source_2_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_2_chaining;
--65
	

create temporary table source_2_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_2;	
--561	










	
-- Source 3 Staging Table -- DrugBank
-- First, explode the synoynms	
CREATE TEMPORARY TABLE exploded_drugbank AS
SELECT DISTINCT 
	d.common_name,
	UNNEST(d.synonyms) as "synonyms"
FROM 
	TREATMENT.SRC_DRUGBANK_VOCABULARY as d;

INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(d.common_name) as drug
	FROM 
		exploded_drugbank as d
	where 
		lower(d.common_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--9639

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(d.synonyms) 
	FROM 
		exploded_drugbank as d 
	where 
		lower(d.synonyms) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--31497


--Second, create DrugBank drug staging 
CREATE TEMPORARY TABLE source_3_preprocessing AS
SELECT DISTINCT 
	d.DrugID as "anchor_id",
	lower(ed.common_name) as "anchor_drug",
	lower(ed.synonyms) as "synonym_name",
	dd.DrugID as "synonym_id",
	3 as source_id
FROM 
	exploded_drugbank as ed
left JOIN Drugs as d
	ON lower(ed.common_name) = d.DrugName
left JOIN Drugs as dd
	ON lower(ed.synonyms) = dd.DrugName
WHERE
		--self reference check
	LOWER(ed.common_name) != LOWER(ed.synonyms);
--31834	
	
create temporary sequence source_3_rowids start 1;

CREATE TEMPORARY TABLE source_3 (
	source_3_rowids INTEGER,
	anchor_id	INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id	INTEGER,
	source_id INTEGER
);

INSERT into source_3
with x as (
	select DISTINCT 
		*
	from 
		source_3_preprocessing
	where synonym_id not in (
			SELECT 
				anchor_id 
			from 
				source_3_preprocessing)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_id,
			synonym_name,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_3_preprocessing
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from 
				source_3_preprocessing)
) select 
	nextval('source_3_rowids') as source_3_rowids,
	x.*
from x;
--31834

CREATE TEMPORARY TABLE source_3_circular_delete AS 
SELECT DISTINCT 
	f1.source_3_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_3 AS f1
JOIN 
	source_3 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--0
	
delete from source_3
where source_3_rowids in (
	select 
		source_3_rowids
	from 
		source_3_circular_delete);
--del 0

create temporary table source_3_swap_delete as
select DISTINCT 
	*
from 
	source_3
where
	anchor_id > synonym_id;
--128
			
delete from source_3
where source_3_rowids in (
	select 
		source_3_rowids
	from 
		source_3_swap_delete);
--del 128

insert into source_3	
select DISTINCT 
	source_3_rowids as 'source_3_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from 
	source_3_swap_delete;
--128

create temporary table source_3_chaining as
select DISTINCT  
	t1.source_3_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_3_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_3 as t1 
join 
	source_3 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--854


delete FROM source_3
WHERE source_3_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_3_chaining);	
--609
	
INSERT INTO source_3
SELECT DISTINCT 
	second_rowid as "source_3_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_3_chaining;
--854
	

create temporary table source_3_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_3;
--32079






	








			
-- Source 4 Staging Table -- RX NORM 
-- Step 1, create a table only for brand names
-- Prep Table 
CREATE TEMPORARY TABLE brand_name AS
SELECT DISTINCT 
	c.rxcui,
	lower(c.str) AS "brand_name",
FROM 
	TREATMENT.rxn_conso as c
WHERE 
	-- BN : brand name
	c.tty = ('BN');	

-- Create a table only for generic names
-- Prep Table
CREATE TEMPORARY TABLE generic AS
SELECT DISTINCT 
	c.rxcui,
	c.tty, 
	lower(c.str) AS "generic_name",
FROM 
	TREATMENT.rxn_conso as c
WHERE
	-- IN : ingredient
	-- MIN : multiple ingredients 
	c.tty in ('IN', 'MIN')
AND 
	-- We define anchors as generic drugs only from rxnorm
	-- all other generic drugs from different sources become synonyms below
	c.sab = ('RXNORM');


-- Join Generic with their synonyms from the different sources without semantic type filtering
-- Table 1 used in source_4_staging_drugs query & used for prep table 
CREATE TEMPORARY TABLE synonyms AS
SELECT DISTINCT 
	g.*,
	lower(c.str) as "synonym_name",
	c.tty
FROM 
	generic as g
JOIN 
	TREATMENT.rxn_conso as c
	ON g.rxcui = c.rxcui
WHERE  
	g.tty != 'BN'
AND 
	LOWER(g.generic_name) != LOWER(c.str);


-- establish relationships between generic drugs and their brand names
-- Prep Table
CREATE TEMPORARY TABLE relationships AS
SELECT DISTINCT 
	r.rxcui1,
	r.rxcui2,
	r.rela
FROM 
	TREATMENT.rxn_rel AS r
WHERE
	r.rela IN ('has_tradename',
				'part_of',
				'reformulated_to');

-- Using the relaitonships we have estiblished above, grab their names, tty, rxcuis, and relationships
-- from Generic and Brand Names tables
-- This table 2 of the source_4_staging_drugs without semantic type filter			
CREATE TEMPORARY TABLE map_relationships AS
SELECT DISTINCT 	
	g.*,
	r.*,
	b.*
FROM relationships AS r
JOIN
	generic AS g
	ON g.rxcui = CAST (r.rxcui1 AS INT)
LEFT OUTER JOIN 
	brand_name as b
	ON CAST (r.rxcui2 AS INT) = b.rxcui;


-- Using the relaitonships we have estiblished above, grab their names, tty, rxcuis, and relationships
-- from Generic and synonym tables
-- Filter out drugs that are brand names
-- This table 3 of the source_4_staging_drugs without semantic type filter			
CREATE TEMPORARY TABLE rela AS
SELECT DISTINCT 
	mr.*,
	lower(c.str) as "synonym_name"
FROM
	map_relationships as mr
	LEFT OUTER JOIN 
		TREATMENT.rxn_conso as c
	ON CAST (mr.rxcui2 AS INT) = c.rxcui
	AND 
		mr.brand_name IS NULL 
	WHERE 
		c.tty != 'BN'
	AND 
		c.suppress = 'N';
	
	
-- we grab all data that is not supressed & the sty type we are interested in	
-- Used as a filtering table in the source_4_staging_drugs query
CREATE TEMPORARY TABLE filtering_types AS
WITH not_suppressed AS (
		SELECT DISTINCT
			s.rxcui
		FROM 
			TREATMENT.rxn_sat as s
		WHERE 
			s.suppress = 'N'),	
	semantic_type AS (
		SELECT DISTINCT 
			sty.rxcui
		FROM 
			TREATMENT.rxn_sty as sty
		WHERE 
			sty.sty in ('Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance') 
) SELECT 
	ns.*,
	st.*
FROM 
	not_suppressed AS ns
INNER JOIN
	semantic_type as st
	on ns.rxcui = st.rxcui;

-- Finally, put it all together!
-- Table 1 [synonyms], 2 [map relationships], and 3 [rela] with the semantic type filtering table

INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(s.generic_name) as drug
	FROM 
		synonyms AS s
	INNER JOIN 
		filtering_types AS ft
	ON 
		s.rxcui = ft.rxcui
	where 
		lower(s.generic_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
UNION
	SELECT DISTINCT 
		lower(mr.generic_name) AS drug
	FROM 
		map_relationships AS mr
	INNER JOIN 
		filtering_types AS ft
		ON mr.rxcui = ft.rxcui
	where 
		lower(mr.generic_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
UNION 
	SELECT DISTINCT 
		lower(re.generic_name) as drug
	FROM
		rela AS re
	INNER JOIN 
		filtering_types AS ft
		ON re.rxcui = ft.rxcui
	where 
		lower(re.generic_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--5462

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(s.synonym_name) 
	FROM 
	synonyms AS s
	INNER JOIN 
		filtering_types AS ft
		ON s.rxcui = ft.rxcui
	WHERE 
		lower(s.synonym_name) IS NOT NULL
	and 
		lower(s.synonym_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
union
	select DISTINCT 
		lower(mr.brand_name)
	FROM 
		map_relationships AS mr
	INNER JOIN 
		filtering_types AS ft
		ON mr.rxcui = ft.rxcui
	WHERE 
		lower(mr.brand_name) IS NOT NULL
	and 
		lower(mr.brand_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
union
	SELECT DISTINCT 
		lower(re.synonym_name)
	FROM
		rela AS re
	INNER JOIN 
		filtering_types AS ft
		ON re.rxcui = ft.rxcui
	WHERE 
		lower(re.synonym_name) IS NOT NULL
	and 
		lower(re.synonym_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--18847



CREATE TEMPORARY TABLE source_4_id_prep AS
SELECT DISTINCT	
	lower(s.generic_name) AS "anchor_drug",
	lower(s.synonym_name) AS "synonym_name",
	4 AS source_id
FROM 
	synonyms AS s
INNER JOIN 
		filtering_types AS ft
		ON s.rxcui = ft.rxcui
	WHERE 
		lower(s.synonym_name) IS NOT NULL
UNION 	
	SELECT DISTINCT 
		lower(mr.generic_name) AS "anchor_drug",
		lower(mr.brand_name) AS "synonym_name",
		4 AS source_id
	FROM 
		map_relationships AS mr
		INNER JOIN 
			filtering_types AS ft
			ON mr.rxcui = ft.rxcui
		WHERE 
			lower(mr.brand_name) IS NOT NULL
UNION 
	SELECT DISTINCT 
		lower(re.generic_name) AS "anchor_drug",
		lower(re.synonym_name) AS "synonym_name",
		4 AS source_id
	FROM
		rela AS re
		INNER JOIN 
			filtering_types AS ft
			ON re.rxcui = ft.rxcui
			WHERE 
				lower(re.synonym_name) IS NOT NULL;

create temporary table source_4_preprocessing as
select 
	d.DrugID as "anchor_id",
	s.anchor_drug,
	s.synonym_name,
	dd.DrugId as "synonym_id",
	source_id
from source_4_id_prep as s
left JOIN Drugs as d
	ON lower(s.anchor_drug) = d.DrugName
left JOIN Drugs as dd
	ON lower(s.synonym_name) = dd.DrugName;
--43675
		
create temporary sequence source_4_rowids start 1;

CREATE TEMPORARY TABLE source_4 (
	source_4_rowids INTEGER,
	anchor_id INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	source_id INTEGER
);

INSERT into source_4
with x as (
		select DISTINCT 
			*
		from 
			source_4_preprocessing
		where synonym_id not in (
			SELECT 
				anchor_id 
			from 
				source_4_preprocessing)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_id,
			synonym_name,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_4_preprocessing
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from 
				source_4_preprocessing)
) select  
	nextval('source_4_rowids') as source_4_rowids,
	x.*
from x;	
--43675

CREATE TEMPORARY TABLE source_4_circular_delete AS 
SELECT DISTINCT 
	f1.source_4_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_4 AS f1
JOIN 
	source_4 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--0
	
delete from source_4
where source_4_rowids in (
	select 
		source_4_rowids
	from 
		source_4_circular_delete);
--del 0

create temporary table source_4_swap_delete as
select DISTINCT 
	*
from 
	source_4
where
	anchor_id > synonym_id;
--8807
			
delete from source_4
where source_4_rowids in (
	select 
		source_4_rowids
	from 
		source_4_swap_delete);
--del 8807

insert into source_4	
select DISTINCT 
	source_4_rowids as 'source_4_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from 
	source_4_swap_delete;
--8807

create temporary table source_4_chaining as
select DISTINCT  
	t1.source_4_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_4_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_4 as t1 
join 
	source_4 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--78333


delete FROM source_4 
WHERE source_4_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_4_chaining);	
--13884
	
INSERT INTO source_4
SELECT DISTINCT 
	second_rowid as "source_4_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_4_chaining;
--78333
	

--create temporary table source_4_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_4;	
--70158








		

		

-- Source 5 Staging Table (NCI Thesaurus) 
INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(s.preferred_name) as drug
	FROM 
		treatment.SRC_NCI_THESAURUS as s
	where 
		semantic_type in ('Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance')
		and 
			lower(s.preferred_name) NOT IN (
				select 
					DrugName 
				from 
					Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--13784

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(n.synonyms_and_abbreviations) 
	FROM 
		treatment.SRC_NCI_THESAURUS as n
	where 
		semantic_type in ('Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance')
		and 
			lower(n.synonyms_and_abbreviations) NOT IN (
				select 
					DrugName 
				from 
					Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--8222

CREATE TEMPORARY TABLE source_5_preprocessing as 
SELECT DISTINCT 
	d.DrugID as "anchor_id",
	lower(n.preferred_name) as "anchor_drug",
	lower(n.synonyms_and_abbreviations) as "synonym_name",
	dd.DrugID as synonym_id,
	5 as source_id
FROM 
	TREATMENT.SRC_NCI_THESAURUS as n
left JOIN Drugs as d
	ON lower(n.preferred_name) = d.DrugName
left JOIN Drugs as dd
	ON lower(n.synonyms_and_abbreviations) = dd.DrugName
WHERE
		semantic_type in ('Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance')
and
	--self references checked here
	lower(n.preferred_name) != lower(n.synonyms_and_abbreviations); 
--9725
	
create temporary sequence source_5_rowids start 1;

CREATE TEMPORARY TABLE source_5 (
	source_5_rowids INTEGER,
	anchor_id INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	source_id INTEGER
);

INSERT into source_5
with x as (
	select DISTINCT 
		*
	from 
		source_5_preprocessing
	where synonym_id not in (
			SELECT 
				anchor_id 
			from 
				source_5_preprocessing)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_id,
			synonym_name,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_5_preprocessing
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from 
				source_5_preprocessing)
) select 
	nextval('source_5_rowids') as source_5_rowids,
	x.*
from x;	
--9725

CREATE TEMPORARY TABLE source_5_circular_delete AS 
SELECT DISTINCT 
	f1.source_5_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_5 AS f1
JOIN 
	source_5 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--0
	
delete from source_5
where source_5_rowids in (
	select 
		source_5_rowids
	from 
		source_5_circular_delete);
--del 0

create temporary table source_5_swap_delete as
select DISTINCT 
	*
from 
	source_5
where
	anchor_id > synonym_id;
--213
			
delete from source_5
where source_5_rowids in (
	select 
		source_5_rowids
	from 
		source_5_swap_delete);
--del 213

insert into source_5	
select DISTINCT 
	source_5_rowids as 'source_5_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from 
	source_5_swap_delete;
--213

create temporary table source_5_chaining as
select DISTINCT  
	t1.source_5_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_5_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_5 as t1 
join 
	source_5 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--13


delete FROM source_5 
WHERE source_5_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_5_chaining);	
--13
	
INSERT INTO source_5
SELECT DISTINCT 
	second_rowid as "source_5_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_5_chaining;
--13
	

create temporary table source_5_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_5;	
--9725










-- Source 6 Staging Table (AACT)
--CREATE TEMPORARY TABLE source_6_preprocessing AS
--SELECT DISTINCT 
--	lower(a.name) as "anchor_drug",
--	lower(o.name) as "synonym_name",
--	6 as source_id
--FROM 
--	TREATMENT.SRC_AACT_INTERVENTIONS as a
--JOIN 
--	TREATMENT.SRC_AACT_INTERVENTIONS_OTHER as o
--	on 
--		a.id = o.intervention_id 
--where 
--	a.intervention_type like ('DRUG')
--and 
--	lower(a.name) != lower(o.name);
--
--create temporary sequence source_6_rowids start 1;
--
--CREATE TEMPORARY TABLE source_6 (
--	source_6_rowids INTEGER,
--	anchor_drug VARCHAR,
--	synonym_name VARCHAR,
--	source_id INTEGER
--);
--
--INSERT into source_6
--with x as (
--	select DISTINCT 
--		*
--	from 
--		source_6_preprocessing
--) select 
--	nextval('source_6_rowids') as source_6_rowids,
--	x.*
--from x;	
--	
--CREATE TEMPORARY TABLE source_6_circular AS 
--SELECT DISTINCT
--	f2.source_6_rowids,
--	f2.anchor_drug,
--	f2.synonym_name,
--	f2.source_id
--FROM 
--	source_6 AS f1
--JOIN 
--	source_6 AS f2
--	ON
--		f1.anchor_drug = f2.synonym_name
--	AND 
--		f1.synonym_name = f2.anchor_drug;
--		
--delete from source_6
--where source_6_rowids in (
--	select 
--		source_6_rowids
--	from 
--		source_6_circular);	
--	
--create temporary table source_6_staging_drugs as
--select DISTINCT 
--	anchor_drug,
--	synonym_name,
--	source_id
--from 
--	source_6;	






	
	
	
-- Source 7 Staging Table (SEER RX)
CREATE TEMPORARY TABLE exploded_seer AS
SELECT DISTINCT 
	lower(sr.name) as "name",
	lower(UNNEST(sr.alternate_name)) as "synonyms"
FROM 
	TREATMENT.SRC_SEER_RX_DRUGS as sr;	

INSERT INTO Drugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(sr.name) as drug
	FROM 
		exploded_seer as sr
	where 
		lower(sr.name) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--488

INSERT INTO Drugs
WITH ListDrugs AS (
	select DISTINCT 
		lower(sr.synonyms) 
	FROM 
		exploded_seer as sr 
	where 
		lower(sr.synonyms) NOT IN (
			select 
				DrugName 
			from 
				Drugs)
) SELECT 
	nextval('DrugID') as DrugID,
	b.*
FROM 
	ListDrugs as b;
--4300
	
CREATE TEMPORARY TABLE source_7_preprocessing AS
SELECT DISTINCT 
	d.DrugID as "anchor_id",
	sr.name as "anchor_drug",
	sr.synonyms as "synonym_name",
	dd.DrugID as "synonym_id",
	7 as source_id
FROM 
	exploded_seer as sr
left JOIN Drugs as d
	ON lower(sr.name) = d.DrugName
left JOIN Drugs as dd
	ON lower(sr.synonyms) = dd.DrugName
where 
	--check for self references
	sr.name != sr.synonyms;
--5758

create temporary sequence source_7_rowids start 1;

CREATE TEMPORARY TABLE source_7 (
	source_7_rowids INTEGER,
	anchor_id INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	source_id INTEGER
);

INSERT into source_7
with x as (
	select DISTINCT 
		*
	from 
		source_7_preprocessing
	where synonym_id not in (
			SELECT 
				anchor_id 
			from 
				source_7_preprocessing)
	UNION
		--SWAP
		SELECT DISTINCT
			synonym_id,
			synonym_name,
			anchor_drug,
			anchor_id,
			source_id
		FROM source_7_preprocessing
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from 
				source_7_preprocessing)
) select 
	nextval('source_7_rowids') as source_7_rowids,
	x.*
from x;	
--5758

CREATE TEMPORARY TABLE source_7_circular_delete AS 
SELECT DISTINCT 
	f1.source_7_rowids,
	f1.anchor_drug,
	f1.synonym_name,
	f1.source_id
FROM 
	source_7 AS f1
JOIN 
	source_7 AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug
	WHERE 
		f1.anchor_id > f1.synonym_id;
--15
	
delete from source_7
where source_7_rowids in (
	select 
		source_7_rowids
	from 
		source_7_circular_delete);
--del 15

create temporary table source_7_swap_delete as
select DISTINCT 
	*
from 
	source_7
where
	anchor_id > synonym_id;
--430
			
delete from source_7
where source_7_rowids in (
	select 
		source_7_rowids
	from 
		source_7_swap_delete);
--del 430

insert into source_7	
select DISTINCT 
	source_7_rowids as 'source_7_rowids',
	synonym_id as 'anchor_id',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	source_id as 'source_id'
from 
	source_7_swap_delete;
--430

create temporary table source_7_chaining as
select DISTINCT  
	t1.source_7_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_7_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", -- as "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.source_id as "second_source_id"
from 
	source_7 as t1 
join 
	source_7 as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
		t1.anchor_drug != t2.synonym_name;	
--1861


delete FROM source_7 
WHERE source_7_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_7_chaining);	
--1253
	
INSERT INTO source_7
SELECT DISTINCT 
	second_rowid as "source_7_rowids",
	first_anchor_id as "anchor_id",
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name",
	second_syn_id as "synonym_id",
	second_source_id as "source_id"
FROM 
	source_7_chaining;
--1861
	

create temporary table source_7_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_7;
--6288	







-- This next section of code creates the final staging table for drugs
-- First, create the shell table
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

create temporary table anchors as
select DISTINCT 
	anchor_drug
from Final_Drug_Staging_Table;

select count(*) from anchors;
--382


---- Insert CanMed
-- This step inserts all anchor drugs from source 2 that dont exist as a snyonym in hemonc
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
--2105

create temporary table source_2_swaps_final as
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

select count(*) from source_2_swaps_final;
--11

--11 deleted
delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_2_swaps_final);
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_2_swaps_final;
--11

select count(*) from Final_Drug_Staging_Table;
--2105

CREATE TEMPORARY TABLE source_2_circular_final AS 
SELECT DISTINCT
	f2.final_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	Final_Drug_Staging_Table AS f1
JOIN 
	Final_Drug_Staging_Table AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
select count(*) from source_2_circular_final;
--0

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_2_circular_final);	
--0
	
CREATE TEMPORARY TABLE source_2_chaining_final as		
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
	
select count(*) from source_2_chaining_final;
--131

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM source_2_chaining_final
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;	
--97

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM source_2_chaining_final)
delete FROM Final_Drug_Staging_Table
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);
--97
	
select count(*) from Final_Drug_Staging_Table;
--2105

				
--INSERT the swapped anchor drug syns if the syns exists as an anchor drug in hemonc  
-- here we swap the order they are inserted because it's the order that matters; not the names		
--CREATE TEMPORARY TABLE source_2_swaps as


-- Insert DrugBank
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		s3.source_id,
		s3.anchor_drug,
		s3.synonym_name
	FROM	
		source_3_staging_drugs as s3)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--31834

select count(*) from Final_Drug_Staging_Table;
--33939

create temporary table source_3_swaps_final as
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

select count(*) from source_3_swaps_final;
--16

--16 deleted
delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_3_swaps_final);
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_3_swaps_final;
--16

select count(*) from Final_Drug_Staging_Table;
--33939

CREATE TEMPORARY TABLE source_3_circular_final AS 
SELECT DISTINCT
	f2.final_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	Final_Drug_Staging_Table AS f1
JOIN 
	Final_Drug_Staging_Table AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
select count(*) from source_3_circular_final;
--0

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_3_circular_final);	
--0
	
CREATE TEMPORARY TABLE source_3_chaining_final as		
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
	
select count(*) from source_3_chaining_final;
--281

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM source_3_chaining_final
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;	
--217

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM source_3_chaining_final)
delete FROM Final_Drug_Staging_Table
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);
--217
	
	
	
	
	
	
	
	
	
	
-- Insert RX Norm
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		s4.source_id,
		s4.anchor_drug,
		s4.synonym_name
	FROM	
		source_4_staging_drugs as s4)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--43389

select count(*) from Final_Drug_Staging_Table;
--77328

create temporary table source_4_swaps_final as
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

select count(*) from source_4_swaps_final;
--11

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_4_swaps_final);
--
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_4_swaps_final;
--11

select count(*) from Final_Drug_Staging_Table;
--77328

CREATE TEMPORARY TABLE source_4_circular_final AS 
SELECT DISTINCT
	f2.final_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	Final_Drug_Staging_Table AS f1
JOIN 
	Final_Drug_Staging_Table AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
select count(*) from source_4_circular_final;
--1298

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_4_circular_final);	
--1198

CREATE TEMPORARY TABLE source_4_chaining_final as		
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
	
select count(*) from source_4_chaining_final;
--3237

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM source_4_chaining_final
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;	
--3136

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM source_4_chaining_final)
delete FROM Final_Drug_Staging_Table
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);
--2948

select count(*) from Final_Drug_Staging_Table;
--76218






-- Insert NCI Thesaurus
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		s5.source_id,
		s5.anchor_drug,
		s5.synonym_name
	FROM	
		source_5_staging_drugs as s5)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--9725

select count(*) from Final_Drug_Staging_Table;
--85943

create temporary table source_5_swaps_final as
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

select count(*) from source_5_swaps_final;
--7


--7 deleted
delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_5_swaps_final);
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_5_swaps_final;
--7

select count(*) from Final_Drug_Staging_Table;
--85943

CREATE TEMPORARY TABLE source_5_circular_final AS 
SELECT DISTINCT
	f2.final_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	Final_Drug_Staging_Table AS f1
JOIN 
	Final_Drug_Staging_Table AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
select count(*) from source_5_circular_final;
--58

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_5_circular_final);	
--58

	
CREATE TEMPORARY TABLE source_5_chaining_final as		
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
	
select count(*) from source_5_chaining_final;
--919

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM source_5_chaining_final
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;	
--894

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM source_5_chaining_final)
delete FROM Final_Drug_Staging_Table
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);
--812



---- Insert AACT
--WITH Uniq AS (
--	SELECT DISTINCT synonym_name
--	FROM Final_Drug_Staging_Table
--)
--INSERT INTO Final_Drug_Staging_Table
--SELECT DISTINCT 
--	s6.source_id,
--	s6.anchor_drug,
--	s6.synonym_name
--FROM	
--source_6_staging_drugs as s6
--WHERE s6.anchor_drug NOT IN (
--				SELECT DISTINCT synonym_name 
--				FROM Uniq);
--			
--WITH Uniq AS (
--	SELECT DISTINCT anchor_drug
--	FROM Final_Drug_Staging_Table
--)
--INSERT INTO Final_Drug_Staging_Table
--SELECT DISTINCT 
--	s6.source_id,
--	s6.synonym_name AS 'anchor_drug',
--	s6.anchor_drug AS 'synonym_name'
--FROM	
--	source_6_staging_drugs as s6
--WHERE s6.synonym_name IN (
--				SELECT DISTINCT anchor_drug 
--				FROM Uniq);


---- Insert SEER RX
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		s7.source_id,
		s7.anchor_drug,
		s7.synonym_name
	FROM	
		source_7_staging_drugs as s7)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--5785

select count(*) from Final_Drug_Staging_Table;
--91752

create temporary table source_7_swaps_final as
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

select count(*) from source_7_swaps_final;
--93


--93 deleted
delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_7_swaps_final);
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	source_id as 'source_id',
	anchor_drug as 'anchor_drug',
	synonym_name as 'synonym_name'
from source_7_swaps_final;
--93

select count(*) from Final_Drug_Staging_Table;
--91752

CREATE TEMPORARY TABLE source_7_circular_final AS 
SELECT DISTINCT
	f2.final_rowids,
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	Final_Drug_Staging_Table AS f1
JOIN 
	Final_Drug_Staging_Table AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
select count(*) from source_7_circular_final;
--47

delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		source_7_circular_final);	
--47
	
CREATE TEMPORARY TABLE source_7_chaining_final as		
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
	
select count(*) from source_7_chaining_final;
--2305

INSERT INTO Final_Drug_Staging_Table
WITH x AS (
	SELECT DISTINCT 
		second_source AS "source_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name"
	FROM source_7_chaining_final
) SELECT 
	nextval('final_rowids') AS final_rowids,
	x.*
FROM x;	
--1836

with chains_drop as (
	SELECT DISTINCT 
		second_rowid
	FROM source_7_chaining_final)
delete FROM Final_Drug_Staging_Table
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chains_drop);
--1842
	
	
	
			
			
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
	
	
	
--CHECK TO make sure ALL circuluar ARE gone			
select DISTINCT 
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
from 
	Final_Drug_Staging_Table as f1
join 
	Final_Drug_Staging_Table as f2
on 
	f1.anchor_drug = f2.synonym_name
and 
	f1.synonym_name = f2.anchor_drug;
			
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



--Chaining references
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




