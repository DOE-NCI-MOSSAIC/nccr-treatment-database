-- DOCUMENTATION: See README.md
-- This file creates all staging files for Drugs. 
CREATE TEMPORARY SEQUENCE DrugID start 1;

--Drug shell table; This will list all unique drugs in each
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
--5788

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
--104783

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
	ON h.concept_code = c.concept_code
LEFT JOIN hcss AS s 
	on c.concept_code = s.synonym_concept_code
left JOIN Drugs as d
	ON lower(h.concept_name) = d.DrugName
left JOIN Drugs as dd
	ON lower(s.synonym_name) = dd.DrugName
WHERE
		--self references
	lower(h.concept_name) != lower(s.synonym_name)
or 
	h.concept_name IS NULL;
--2111


--CREATE COMPOSITE DRUG TABLE
CREATE TEMPORARY TABLE CompositeDrug AS
SELECT *
FROM source_1_preprocessing
WHERE anchor_drug like '% and %';

--DELETE COMPOSITE DRUGS FROM DRUG TABLE
DELETE 
FROM source_1_preprocessing
WHERE anchor_drug like '% and %';

create temporary sequence source_1_rowids start 1;

CREATE TEMPORARY TABLE source_1 (
	source_1_rowids INTEGER,
	anchor_id	INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	source_id INTEGER
);

INSERT INTO source_1
WITH x AS (
	SELECT DISTINCT 
		*
	FROM 
		source_1_preprocessing
	WHERE synonym_id NOT IN (
		SELECT 
			anchor_id 
		FROM source_1_preprocessing)
		AND synonym_id NOT IN 
		(SELECT
			anchor_id
		FROM CompositeDrug)
	UNION
	--SWAP
	SELECT DISTINCT
		synonym_id,
		synonym_name,
		anchor_drug,
		anchor_id,
		source_id
	FROM source_1_preprocessing
	WHERE synonym_id IN (
		SELECT 
			anchor_id 
		FROM source_1_preprocessing)
) SELECT 
	nextval('source_1_rowids') as source_1_rowids,
	x.*
from x;	
--2082

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
--1

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
--0
	
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
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_1_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", 
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
--0

INSERT INTO source_1
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_source_id as "source_id"
	FROM 
		source_1_chaining
) select 
	nextval('source_1_rowids') as source_1_rowids,
	x.*
from x;
--0


create temporary table source_1_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name
from 
	source_1;	
--2081

---------------------------------------------
-- Source 2 Staging Table -- CanMed
---------------------------------------------
create temporary sequence DrugID2 start 1;

create temporary table Drugs2 (
	DrugID2 INTEGER,
	DrugName VARCHAR
);

INSERT INTO Drugs2
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(c.generic_name) as drug
	FROM 
		treatment.canmed_ndc c
) SELECT 
	nextval('DrugID2') as DrugID2,
	b.*
FROM 
	ListDrugs as b;
--457

INSERT INTO Drugs2
WITH ListDrugs AS (
	select DISTINCT 
		lower(cn.brand_name) as drug
	FROM 
		treatment.canmed_ndc cn 
	where 
		lower(cn.brand_name) NOT IN (
			select 
				DrugName 
			from 
				Drugs2)
) SELECT 
	nextval('DrugID2') as DrugID2,
	b.*
FROM 
	ListDrugs as b;
--467

CREATE TEMPORARY TABLE source_2_preprocessing AS 
SELECT DISTINCT 
	d.DrugID2 as "anchor_id",
	lower(c.generic_name) as "anchor_drug",
	lower(c.brand_name) as "synonym_name",
	dd.DrugID2 as "synonym_id",
	2 as source_id
FROM 
	TREATMENT.canmed_ndc as c
left JOIN Drugs2 as d
	ON lower(c.generic_name) = d.DrugName
left JOIN Drugs2 as dd
	ON lower(c.brand_name) = dd.DrugName
WHERE
	--self references
	LOWER(c.generic_name) != LOWER(c.brand_name);
--549

INSERT INTO CompositeDrug
SELECT *
FROM source_2_preprocessing
WHERE anchor_drug like '% and %';
--16


DELETE 
FROM source_2_preprocessing
WHERE anchor_drug like '% and %';


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
--533

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
--8

create temporary table source_2_swap_delete as
select DISTINCT 
	*
from 
	source_2
where
	anchor_id > synonym_id;
--9			

delete from source_2
where source_2_rowids in (
	select 
		source_2_rowids
	from 
		source_2_swap_delete);
--9

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
--9

create temporary table source_2_chaining as
select DISTINCT  
	t1.source_2_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_2_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", 
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
--32
	
delete FROM source_2 
WHERE source_2_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_2_chaining);	
--32
	
INSERT INTO source_2
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_source_id as "source_id"
	FROM 
		source_2_chaining
) select 
	nextval('source_2_rowids') as source_2_rowids,
	x.*
from x;
--32

create temporary table source_2_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_2;	
--518

--------------------------------------------------
-- Source 3 Staging Table -- DrugBank
--------------------------------------------------
CREATE TEMPORARY TABLE exploded_drugbank AS
SELECT DISTINCT 
	d.common_name,
	UNNEST(d.synonyms) as "synonyms"
FROM 
	TREATMENT.SRC_DRUGBANK_VOCABULARY as d;

--DELETE TWO RECORDS WITH "and" BECAUSE THEY ARE NOT CANCER DRUGS
DELETE 
FROM exploded_drugbank
WHERE common_name LIKE '% and %';
--DRUGS WITH "and" AS A SYNONYM SHOULD BE OK

create temporary sequence DrugID3 start 1;

create temporary table Drugs3 (
	DrugID3 INTEGER,
	DrugName VARCHAR
);

INSERT INTO Drugs3
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(d.common_name) as drug
	FROM 
		exploded_drugbank as d
) SELECT 
	nextval('DrugID3') as DrugID3,
	b.*
FROM 
	ListDrugs as b;
--10311

INSERT INTO Drugs3
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
				Drugs3)
) SELECT 
	nextval('DrugID3') as DrugID3,
	b.*
FROM 
	ListDrugs as b;
--31828

CREATE TEMPORARY TABLE source_3_preprocessing AS
SELECT DISTINCT 
	d.DrugID3 as "anchor_id",
	lower(ed.common_name) as "anchor_drug",
	lower(ed.synonyms) as "synonym_name",
	dd.DrugID3 as "synonym_id",
	3 as source_id
FROM 
	exploded_drugbank as ed
left JOIN Drugs3 as d
	ON lower(ed.common_name) = d.DrugName
left JOIN Drugs3 as dd
	ON lower(ed.synonyms) = dd.DrugName
WHERE
		--self reference
	LOWER(ed.common_name) != LOWER(ed.synonyms);
--31832
	
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
--31832

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
--0

create temporary table source_3_swap_delete as
select DISTINCT 
	*
from 
	source_3
where
	anchor_id > synonym_id;
--3
			
delete from source_3
where source_3_rowids in (
	select 
		source_3_rowids
	from 
		source_3_swap_delete);
--3

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
--3

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
--21

delete FROM source_3
WHERE source_3_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_3_chaining);	
--21
	
INSERT INTO source_3
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_source_id as "source_id"
	FROM 
		source_3_chaining
) select 
	nextval('source_3_rowids') as source_3_rowids,
	x.*
from x;
--21

create temporary table source_3_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_drug,
	synonym_id,
	synonym_name,
	source_id
from 
	source_3;
--31832


-------------------------------------------------------------
-- Source 4 Staging Table -- RX NORM 
-- Step 1, create a table only for brand names
-- Included SAB = 'RXNORM' and expanded past BN. This allows us to include drugs without BN
-- http://nlm.nih.gov/research/umls/rxnorm/docs/appendix5.html
-- Added Suppress = 'N'. 
-------------------------------------------------------------

CREATE TEMPORARY TABLE brand_name AS
SELECT DISTINCT 
	c.rxcui,
	c.tty,
	lower(c.str) AS "brand_name",
FROM 
	TREATMENT.rxn_conso as c
		JOIN TREATMENT.rxn_sty rs 
		ON c.rxcui = rs.rxcui
WHERE 
	-- BN : brand name
	c.tty IN ('IN',
	'PIN', 
	'MIN', 
	'BN', 
	'SDC', 
	'SCDF', 
	'SCDFP', 
	'SCDG', 
	'SCDGP', 
	'SCD', 
	'GPCK', 
	'SBDC', 
	'SBDF',
	'SBDFP', 
	'SBDG', 
	'SBD', 
	'BPCK', 
	'DF', 
	'DFG')
	AND SAB = 'RXNORM'
	AND c.suppress = 'N'
	AND rs.sty in
	(	'Amino Acid, Peptide, or Protein',
		'Antibiotic',
		'Enzyme',
		'Hormone',
		'Hazardous or Poisonous Substance',
		'Immunologic Factor',
		'Inorganic Chemical',
		'Nucleic Acid, Nucleoside, or Nucleotide',
		'Organic Chemical',
		'Pharmacologic Substance');



CREATE TEMPORARY TABLE synonyms AS
SELECT DISTINCT 
   b.rxcui,
   b.tty,
   b.brand_name,
   lower(c.str) AS synonym_name,
   c.tty
FROM
	brand_name as b
JOIN TREATMENT.rxn_conso as c
ON b.rxcui = c.rxcui
WHERE 
	LOWER(b.brand_name) != LOWER(c.str)
	and SAB = 'RXNORM';

-- establish relationships between generic drugs and their brand names

CREATE TEMPORARY TABLE relationships AS
SELECT DISTINCT 
	r.rxcui1,
	r.rxcui2,
	r.rela
FROM 
	TREATMENT.rxn_rel AS r
WHERE
	r.rela IN ('has_tradename',
				'has_part',
				'ingredient_of'
				'precise_active_ingredient',
				'precise_ingredient_of');
			
			


CREATE TEMPORARY TABLE map_relationships AS
SELECT DISTINCT b.*,rc.*,rc2.str 
FROM brand_name as b
	JOIN relationships rc 
		LEFT OUTER JOIN TREATMENT.rxn_conso rc2 
		ON rc.rxcui2 = rc2.rxcui 
		AND rc2.sab = 'RXNORM'
	ON b.rxcui = rc.rxcui1;

--INSERT THE FOLLOWING INTO THE COMPOSITE DRUG TABLE
--part_of
--precise_ingredient_of
INSERT INTO CompositeDrug
SELECT DISTINCT rxcui2 AS anchor_id,
	LOWER(str) AS anchor_drug,
	NULL AS synonym_name,
	NULL AS synonym_id,
	4 AS source_id
FROM map_relationships
WHERE rela IN ('precise_ingredient_of','has_part')
AND LOWER(str) NOT IN (
				SELECT anchor_drug_name
				FROM main.Composite_Drugs cd
				WHERE anchor_drug_name like '%-%'
				AND anchor_drug_name not like '% - %'
				AND anchor_drug_name not like '%/%');
--4795

DELETE 
FROM brand_name
WHERE RXCui in (SELECT ANCHOR_ID
				FROM CompositeDrug
				WHERE SOURCE_ID = 4) ;
--4969


CREATE TEMPORARY TABLE composite_drug_components AS
SELECT DISTINCT rxcui2 as anchor_id,
	lower(str) as anchor_drug,
	lower(brand_name) as component_drug,
	rxcui1 as component_drug_id,
	4 as source_id
from map_relationships
where rela in ('precise_ingredient_of','has_part');

create temporary sequence DrugID4 start 1;

create temporary Table Drugs4 (
	DrugID4 INTEGER,
	RXCUI INTEGER,
	DrugName VARCHAR
);

CREATE TEMPORARY TABLE source_4_id_prep AS
SELECT DISTINCT	
	rxcui,
	lower(s.brand_name) AS "anchor_drug",
	lower(s.synonym_name) AS "synonym_name",
	rxcui AS rxcui2,
	4 AS source_id
FROM 
	synonyms AS s
UNION 	
	SELECT DISTINCT 
		rxcui2,
		lower(mr.str) AS "anchor_drug",
		lower(mr.brand_name) AS "synonym_name",
		rxcui,
		4 AS source_id
	FROM 
		map_relationships AS mr
	WHERE 
			rela = 'has_tradename';
--10229

CREATE TEMPORARY TABLE Drugs4Uniq AS
WITH ListDrugs AS (
	SELECT  
		min(rxcui) as RXCUI, 
		lower(s.anchor_drug) as drug
	FROM 
		source_4_id_prep AS s
	GROUP BY lower(s.anchor_drug)
),
ListDrugs2 AS (
	SELECT  
		min(rxcui2) as RXCUI, 
		lower(s.synonym_name) as drug
	FROM 
		source_4_id_prep AS s
	GROUP BY lower(s.synonym_name)
),
ListDrugs3 AS(
		SELECT DISTINCT
		rxcui,
		brand_name
	FROM brand_name
	)
	SELECT 
		b.*,
	FROM 
		ListDrugs as b
UNION
	SELECT 
		bb.*,
	FROM 
		ListDrugs2 as bb
UNION
	 SELECT *
	FROM ListDrugs3;

INSERT INTO Drugs4
SELECT 	nextval('DrugID4') as DrugID4,
	*
FROM Drugs4Uniq;

--23173 

	
create temporary table source_4_preprocessing as
select DISTINCT 
	d.DrugID4 as "anchor_id",
	d.rxcui as "anchor_rxcui",
	s.anchor_drug,
	s.synonym_name,
	dd.DrugId4 as "synonym_id",
	dd.rxcui as "synonym_rxcui",
	source_id
from source_4_id_prep as s
 JOIN Drugs4 as d
	ON s.rxcui = d.rxcui
	and s.anchor_drug = d.DrugName
 JOIN Drugs4 as dd
	ON s.rxcui2 = dd.rxcui
	AND s.synonym_name = dd.DrugName;
--10254


		
create temporary sequence source_4_rowids start 1;

CREATE TEMPORARY TABLE source_4 (
	source_4_rowids INTEGER,
	anchor_id INTEGER,
	anchor_rxcui INTEGER,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INTEGER,
	synonym_rxcui INTEGER,
	source_id INTEGER
);

INSERT INTO source_4
SELECT   
	nextval('source_4_rowids') as source_4_rowids,
	anchor_id,
	anchor_rxcui,
	anchor_drug,
	synonym_name,
	synonym_id,
	synonym_rxcui,
	source_id
FROM source_4_preprocessing;

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
		f1.anchor_rxcui = f2.synonym_rxcui
	AND 
		f1.synonym_rxcui = f2.anchor_rxcui
	AND 
		f1.anchor_drug = f2.synonym_name
	WHERE 
		f1.anchor_id > f1.synonym_id;
--0
	
delete from source_4
where source_4_rowids in (
	select 
		source_4_rowids
	from 
		source_4_circular_delete);
--0


create temporary table source_4_chaining as
select DISTINCT  
	t1.source_4_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_rxcui as "first_anchor_rxcui",
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.synonym_rxcui as "first_syn_rxcui",
	t2.source_4_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_rxcui as "second_anchor_rxcui",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", 
	t2.synonym_id as "second_syn_id",
	t2.synonym_rxcui as "second_syn_rxcui",
	t2.source_id as "second_source_id"
from 
	source_4 as t1 
join 
	source_4 as t2
	on 
		t1.synonym_rxcui = t2.anchor_rxcui
where
		t1.anchor_rxcui != t1.synonym_rxcui
		and t1.anchor_rxcui != t2.anchor_rxcui;	
--0

delete FROM source_4 
WHERE source_4_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_4_chaining);	
--0
	

INSERT INTO source_4
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor_rxcui as "anchor_rxcui",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_syn_rxcui as "synonym_rxcui",
		second_source_id as "source_id"
FROM 
	source_4_chaining
) select 
	nextval('source_4_rowids') as source_4_rowids,
	x.*
from x;
--0

select *
from source_4;

create temporary table source_4_staging_drugs as
select DISTINCT 
	anchor_id,
	anchor_rxcui,
	anchor_drug,
	synonym_id,
	synonym_rxcui,
	synonym_name,
	source_id
from 
	source_4;	
--10254


------------------------------------------------
-- Source 5 Staging Table (NCI Thesaurus) 
------------------------------------------------
create temporary sequence DrugID5 start 1;

create temporary table Drugs5 (
	DrugID5 INTEGER,
	DrugName VARCHAR
);

INSERT INTO Drugs5
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(s.preferred_name) as drug
	FROM 
		treatment.SRC_NCI_THESAURUS as s
	where 
		semantic_type in ('Enzyme', 
						'Antibiotic', 
						'Antibiotic|Organic Chemical|Pharmacologic Substance',
						'Antibiotic|Pharmacologic Substance',
						'Hazardous or Poisonous Substance',
						'Amino Acid, Peptide, or Protein',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance')
) SELECT 
	nextval('DrugID5') as DrugID5,
	b.*
FROM 
	ListDrugs as b;
--23544

INSERT INTO Drugs5
WITH ListDrugs AS (
	select DISTINCT 
		lower(n.synonyms_and_abbreviations) 
	FROM 
		treatment.SRC_NCI_THESAURUS as n
	where 
		semantic_type in ('Enzyme', 
						'Antibiotic', 
						'Antibiotic|Organic Chemical|Pharmacologic Substance',
						'Antibiotic|Pharmacologic Substance',
						'Hazardous or Poisonous Substance',
						'Amino Acid, Peptide, or Protein',
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
					Drugs5)
) SELECT 
	nextval('DrugID5') as DrugID5,
	b.*
FROM 
	ListDrugs as b;
--13005

CREATE TEMPORARY TABLE source_5_preprocessing as 
SELECT DISTINCT 
	d.DrugID5 as "anchor_id",
	lower(n.preferred_name) as "anchor_drug",
	lower(n.synonyms_and_abbreviations) as "synonym_name",
	dd.DrugID5 as synonym_id,
	5 as source_id
FROM 
	TREATMENT.SRC_NCI_THESAURUS as n
left JOIN Drugs5 as d
	ON lower(n.preferred_name) = d.DrugName
left JOIN Drugs5 as dd
	ON lower(n.synonyms_and_abbreviations) = dd.DrugName
WHERE
		semantic_type in ('Enzyme', 
						'Antibiotic', 
						'Antibiotic|Organic Chemical|Pharmacologic Substance',
						'Antibiotic|Pharmacologic Substance',
						'Hazardous or Poisonous Substance',
						'Amino Acid, Peptide, or Protein',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance')
and
	--self references checked here
	lower(n.preferred_name) != lower(n.synonyms_and_abbreviations); 
--14356

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
--14356

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
--0

create temporary table source_5_swap_delete as
select DISTINCT 
	*
from 
	source_5
where
	anchor_id > synonym_id;
--13
			
delete from source_5
where source_5_rowids in (
	select 
		source_5_rowids
	from 
		source_5_swap_delete);
--13

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
--13

create temporary table source_5_chaining as
select DISTINCT  
	t1.source_5_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_drug AS "first_anchor",
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t2.source_5_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn", 
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
--11
	
delete FROM source_5 
WHERE source_5_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_5_chaining);	
--11
	
INSERT INTO source_5
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_source_id as "source_id"
	FROM 
		source_5_chaining
) select 
	nextval('source_5_rowids') as source_5_rowids,
	x.*
from x;	
--11

create temporary table source_5_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	source_5;	
--14356
	
-------------------------------------------------
-- Source 7 Staging Table (SEER RX)
-------------------------------------------------
create temporary sequence DrugID7 start 1;

create temporary table Drugs7 (
	DrugID7 INTEGER,
	DrugName VARCHAR
);

CREATE TEMPORARY TABLE exploded_seer AS
SELECT DISTINCT 
	lower(sr.name) as "name",
	lower(UNNEST(sr.alternate_name)) as "synonyms"
FROM 
	TREATMENT.SRC_SEER_RX_DRUGS as sr;	

INSERT INTO Drugs7
WITH ListDrugs AS (
	SELECT DISTINCT 
		lower(sr.name) as drug
	FROM 
		exploded_seer as sr
) SELECT 
	nextval('DrugID7') as DrugID7,
	b.*
FROM 
	ListDrugs as b;
--1322

INSERT INTO Drugs7
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
				Drugs7)
) SELECT 
	nextval('DrugID7') as DrugID7,
	b.*
FROM 
	ListDrugs as b;
--5537	

CREATE TEMPORARY TABLE source_7_preprocessing AS
SELECT DISTINCT 
	d.DrugID7 as "anchor_id",
	sr.name as "anchor_drug",
	sr.synonyms as "synonym_name",
	dd.DrugID7 as "synonym_id",
	7 as source_id
FROM 
	exploded_seer as sr
left JOIN Drugs7 as d
	ON lower(sr.name) = d.DrugName
left JOIN Drugs7 as dd
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
--15

create temporary table source_7_swap_delete as
select DISTINCT 
	*
from 
	source_7
where
	anchor_id > synonym_id;
--24
			
delete from source_7
where source_7_rowids in (
	select 
		source_7_rowids
	from 
		source_7_swap_delete);
--24
	
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
--24

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
--209
	
delete FROM source_7 
WHERE source_7_rowids IN (
	SELECT 
		second_rowid
	FROM 
		source_7_chaining);	
--201
	
INSERT INTO source_7
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_source_id as "source_id"
	FROM 
		source_7_chaining
) select 
	nextval('source_7_rowids') as source_7_rowids,
	x.*
from x;
--203

create temporary table source_7_staging_drugs as
select DISTINCT 
	anchor_drug,
	synonym_name,
	source_id
from 
	source_7;
--5699

----------------------------------------------------------------------
---------------------------------------------------------------------
----------------------------------------------------------------------
-- This next section of code creates the final staging table for drugs
----------------------------------------------------------------------
---------------------------------------------------------------------
----------------------------------------------------------------------

CREATE TEMPORARY sequence FinalDrugID start 1;

create temporary table FinalDrugs (
	FinalDrugID INTEGER,
	DrugName VARCHAR
);

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_1_staging_drugs 
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--540

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_2_staging_drugs 
	where 
		anchor_drug NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--149

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_3_staging_drugs 
	where 
		anchor_drug NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--7875

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_4_staging_drugs 
	where 
		anchor_drug NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
----2139

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_5_staging_drugs 
	where 
		anchor_drug NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--12777


INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		anchor_drug
	FROM 
		source_7_staging_drugs 
	where 
		anchor_drug NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--699

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_1_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--1965

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_2_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--385

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_3_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--30790

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_4_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--6038

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_5_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--12392

INSERT INTO FinalDrugs
WITH ListDrugs AS (
	SELECT DISTINCT 
		synonym_name
	FROM 
		source_7_staging_drugs 
	where 
		synonym_name NOT IN (
			select DISTINCT 
				DrugName
			from 
				FinalDrugs)
) SELECT 
	nextval('FinalDrugID') as FinalDrugID,
	b.*
FROM 
	ListDrugs as b;
--4277

create temporary sequence final_rowids start 1;

CREATE TEMPORARY TABLE Final_Drug_Staging_Table (
	final_rowids int,
	anchor_id INT,
	anchor_rxcui	INT,
	anchor_drug VARCHAR,
	synonym_name VARCHAR,
	synonym_id INT,
	synonym_rxcui	INT,
	source_id INT,
);

-- Insert HemOnc
-- EDITS MADE HERE
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT
		fd.FinalDrugId as "anchor_id",
		NULL as "anchor_rxcui",
		s1.anchor_drug,
		s1.synonym_name,
		fdd.FinalDrugId as "synonym_id",
		NULL AS "synonym_rxcui",
		1
	FROM	
		source_1_staging_drugs as s1
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s1.anchor_drug 
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s1.synonym_name)
select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--2081

---- Insert CanMed
INSERT INTO Final_Drug_Staging_Table
with x as (
	select	
		fd.FinalDrugId as "anchor_id",
		NULL as "anchor_rxcui",
		s2.anchor_drug,
		s2.synonym_name,
		fdd.FinalDrugId as "synonym_id",
		NULL AS "synonym_rxcui",
		s2.source_id
	FROM	
		source_2_staging_drugs as s2
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s2.anchor_drug 
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s2.synonym_name
	where synonym_id not in (
		SELECT 
			anchor_id
		from 
			Final_Drug_Staging_Table)	
	UNION
		--SWAP
		SELECT DISTINCT
			fdd.FinalDrugId as "anchor_id",
			NULL as "anchor_rxcui",
			s2.synonym_name,
			s2.anchor_drug,
			fd.FinalDrugId as "synonym_id",
			NULL AS "synonym_rxcui",
			s2.source_id
		FROM source_2_staging_drugs as s2
		LEFT JOIN FinalDrugs as fd
			on fd.DrugName = s2.anchor_drug 
		LEFT JOIN FinalDrugs as fdd
			on fdd.DrugName = s2.synonym_name
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from Final_Drug_Staging_Table)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--518

-- Insert DrugBank
INSERT INTO Final_Drug_Staging_Table
with x as (
	select	
		fd.FinalDrugID as "anchor_id",
		NULL as "anchor_rxcui",
		s3.anchor_drug,
		s3.synonym_name,
		fdd.FinalDrugId as "synonym_id",
		NULL AS "synonym_rxcui",
		s3.source_id
	FROM	
		source_3_staging_drugs as s3
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s3.anchor_drug
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s3.synonym_name
	where synonym_id not in (
		SELECT 
			anchor_id 
		from 
			Final_Drug_Staging_Table)
	UNION
		--SWAP
		SELECT DISTINCT
			fdd.FinalDrugId as "anchor_id",
			NULL as "anchor_rxcui",
			s3.synonym_name,
			s3.anchor_drug,
			fd.FinalDrugId as "synonym_id",
			NULL AS "synonym_rxcui",
			s3.source_id
		FROM source_3_staging_drugs as s3
		LEFT JOIN FinalDrugs as fd
			on fd.DrugName = s3.anchor_drug 
		LEFT JOIN FinalDrugs as fdd
			on fdd.DrugName = s3.synonym_name
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from Final_Drug_Staging_Table)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--31832


INSERT INTO Final_Drug_Staging_Table
with x as (
	select	
		fd.FinalDrugId as "anchor_drug",
		s4.anchor_rxcui,
		s4.anchor_drug,
		s4.synonym_name,
		fdd.FinalDrugID as "synonym_id",
		s4.synonym_rxcui,
		s4.source_id
	FROM	
		source_4_staging_drugs as s4
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s4.anchor_drug
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s4.synonym_name
	where synonym_id not in (
		SELECT 
			anchor_id 
		from 
			Final_Drug_Staging_Table)
	UNION
		--SWAP
		SELECT DISTINCT
			fdd.FinalDrugId as "anchor_id",
			s4.synonym_rxcui,
			s4.synonym_name,
			s4.anchor_drug,
			fd.FinalDrugId as "synonym_id",
			s4.anchor_rxcui,
			s4.source_id
		FROM source_4_staging_drugs as s4
		LEFT JOIN FinalDrugs as fd
			on fd.DrugName = s4.anchor_drug 
		LEFT JOIN FinalDrugs as fdd
			on fdd.DrugName = s4.synonym_name
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from Final_Drug_Staging_Table)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--10254

INSERT INTO Final_Drug_Staging_Table
with x as (
	select	
		fd.FinalDrugID as "anchor_id",
		NULL as "anchor_rxcui",
		s5.anchor_drug,
		s5.synonym_name,
		fdd.FinalDrugID as "synonym_id",
		NULL AS "synonym_rxcui",
		s5.source_id
	FROM	
		source_5_staging_drugs as s5
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s5.anchor_drug
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s5.synonym_name
	where synonym_id not in (
		SELECT 
			anchor_id 
		from 
			Final_Drug_Staging_Table)
	UNION
		--SWAP
		SELECT DISTINCT
			fdd.FinalDrugId as "anchor_id",
			NULL as "anchor_rxcui",
			s5.synonym_name,
			s5.anchor_drug,
			fd.FinalDrugId as "synonym_id",
			NULL AS "synonym_rxcui",
			s5.source_id
		FROM source_5_staging_drugs as s5
		LEFT JOIN FinalDrugs as fd
			on fd.DrugName = s5.anchor_drug 
		LEFT JOIN FinalDrugs as fdd
			on fdd.DrugName = s5.synonym_name
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from Final_Drug_Staging_Table)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--15649

INSERT INTO Final_Drug_Staging_Table
with x as (
	select	
		fd.FinalDrugID as "anchor_id",
		NULL as "anchor_rxcui",
		s7.anchor_drug,
		s7.synonym_name,
		fdd.FinalDrugID as "synonym_id",
		NULL AS "synonym_rxcui",
		s7.source_id
	FROM	
		source_7_staging_drugs as s7
	LEFT JOIN FinalDrugs as fd
		on fd.DrugName = s7.anchor_drug
	LEFT JOIN FinalDrugs as fdd
		on fdd.DrugName = s7.synonym_name
	where synonym_id not in (
		SELECT 
			anchor_id 
		from 
			Final_Drug_Staging_Table)
	UNION
		--SWAP
		SELECT DISTINCT
			fdd.FinalDrugId as "anchor_id",
			NULL as "anchor_rxcui",
			s7.synonym_name,
			s7.anchor_drug,
			fd.FinalDrugId as "synonym_id",
			NULL AS "synonym_rxcui",
			s7.source_id
		FROM source_7_staging_drugs as s7
		LEFT JOIN FinalDrugs as fd
			on fd.DrugName = s7.anchor_drug 
		LEFT JOIN FinalDrugs as fdd
			on fdd.DrugName = s7.synonym_name
		WHERE synonym_id in (
			SELECT 
				anchor_id 
			from Final_Drug_Staging_Table)
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--8498

create temporary table final_swap_delete as
select DISTINCT 
	*
from 
	Final_Drug_Staging_Table
where
	anchor_id > synonym_id;
--12429


delete from Final_Drug_Staging_Table
where final_rowids in (
	select 
		final_rowids
	from 
		final_swap_delete) ;
--12429
	
	
insert into Final_Drug_Staging_Table	
select DISTINCT 
	final_rowids as 'final_rowids',
	synonym_id as 'anchor_id',
	synonym_rxcui as 'anchor_rxcui',
	synonym_name as 'anchor_drug',
	anchor_drug as 'synonym_name',
	anchor_id as 'synonym_id',
	anchor_rxcui as 'synonym_rxcui',
	source_id as 'source_id'
from 
	final_swap_delete;
--12429

-- Now, recurisevly remove chaining from the dataset.
-- Everytime we fix a chain, we create a new one. Repeat
-- until they are cleared. 



create temporary table chaining_final as
select DISTINCT  
	t1.final_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_rxcui as "first_anchor_rxcui",
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.synonym_rxcui as "first_syn_rxcui",
	t1.source_id as "first_source_id",
	t2.final_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_rxcui as "second_anchor_rxcui",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.synonym_rxcui as "second_syn_rxcui",
	t2.source_id as "second_source_id"
from 
	Final_Drug_Staging_Table as t1 
join 
	Final_Drug_Staging_Table as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
	t1.synonym_id = t2.anchor_id	
	AND t1.anchor_drug != t2.synonym_name;
--5496
 
delete FROM Final_Drug_Staging_Table 
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chaining_final);	
--3739

INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor_rxcui as "anchor_rxcui",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_syn_rxcui as "synonym_rxcui",
		second_source_id as "source_id"
	FROM 
		chaining_final
) select 
	nextval('final_rowids') as final_rowids,
	x.*,
from x;
--4273

create temporary table chaining_final2 as
select DISTINCT  
	t1.final_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_rxcui as "first_anchor_rxcui",
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.synonym_rxcui as "first_syn_rxcui",
	t1.source_id as "first_source_id",
	t2.final_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_rxcui as "second_anchor_rxcui",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.synonym_rxcui as "second_syn_rxcui",
	t2.source_id as "second_source_id"
from 
	Final_Drug_Staging_Table as t1 
join 
	Final_Drug_Staging_Table as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
	t1.synonym_id = t2.anchor_id	
	AND t1.anchor_drug != t2.synonym_name;
--195

delete FROM Final_Drug_Staging_Table 
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chaining_final2);	
--169
	
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor_rxcui as "anchor_rxcui",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_syn_rxcui as "synonym_rxcui",
		second_source_id as "source_id"
	FROM 
		chaining_final2
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--139

create temporary table chaining_final3 as
select DISTINCT  
	t1.final_rowids AS "first_rowid",
	t1.anchor_id as "first_anchor_id",
	t1.anchor_rxcui as "first_anchor_rxcui",
	t1.anchor_drug AS "first_anchor", 
	t1.synonym_name as "first_syn",
	t1.synonym_id as "first_syn_id",
	t1.synonym_rxcui as "first_syn_rxcui",
	t1.source_id as "first_source_id",
	t2.final_rowids AS "second_rowid",
	t2.anchor_id as "second_anchor_id",
	t2.anchor_rxcui as "second_anchor_rxcui",
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "second_syn",
	t2.synonym_id as "second_syn_id",
	t2.synonym_rxcui as "second_syn_rxcui",
	t2.source_id as "second_source_id"
from 
	Final_Drug_Staging_Table as t1 
join 
	Final_Drug_Staging_Table as t2
	on 
		t1.synonym_name = t2.anchor_drug
where
	t1.synonym_id = t2.anchor_id	
	AND t1.anchor_drug != t2.synonym_name;
--0 

delete FROM Final_Drug_Staging_Table 
WHERE final_rowids IN (
	SELECT 
		second_rowid
	FROM 
		chaining_final3);	
--0
	
INSERT INTO Final_Drug_Staging_Table
with x as (
	SELECT DISTINCT 
		first_anchor_id as "anchor_id",
		first_anchor_rxcui as "anchor_rxcui",
		first_anchor AS "anchor_drug",
		second_syn AS "synonym_name",
		second_syn_id as "synonym_id",
		second_syn_rxcui as "synonym_rxcui",
		second_source_id as "source_id"
	FROM 
		chaining_final3
) select 
	nextval('final_rowids') as final_rowids,
	x.*
from x;
--0


-- Total Count:
-- 108586

create temporary table Drug_Staging_Table as
select DISTINCT 
	*
from Final_Drug_Staging_Table;
--69336

