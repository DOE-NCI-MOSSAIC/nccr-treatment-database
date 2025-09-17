-- This is the code base for creating the staging table for RX Norm
 
-- First, grab all the data that is NOT suppressed
create temporary table supress as
--rxcui, rxaui, code
SELECT DISTINCT
	s.rxcui
from 
	treatment.rxn_sat as s
where 
	s.suppress like ('N');

SELECT DISTINCT count(*)
FROM supress;

-- Second, grab all the data that is matching the semantic types defined by Austin
CREATE TEMPORARY TABLE semantic_type AS
--rxcui
SELECT DISTINCT *
FROM 
	treatment.rxn_sty as s
	WHERE 
		s.sty LIKE ('Enzyme')
	OR 
		s.sty LIKE ('Antibiotics')
	OR 
		s.sty LIKE ('Hazardous or Poisonous Substance')
	OR 
		s.sty LIKE ('Amino Acids, Peptides, and Proteins')
	OR 
		s.sty LIKE ('Immunologic Factor')
	OR 
		s.sty LIKE ('Inorganic Chemical')
	OR 
		s.sty LIKE ('Nucleic Acid, Nucleoside, or Nucleotide')
	OR 
		s.sty LIKE ('Organic Chemical')
	OR 
		s.sty LIKE ('Pharmacologic Substance');

SELECT *
FROM semantic_type;
	
-- Third, create a table only for brand names
CREATE TEMPORARY TABLE brand_name AS
-- rxcui, rxaui, str, code
SELECT DISTINCT 
	--b.tty,
	b.rxcui,
	b.rxaui,
	b.code,
	b.str AS "brand_name",
FROM 
	treatment.rxn_conso as b
where 
	b.tty LIKE ('BN');

SELECT *
FROM brand_name;


-- Fouth, create a table only for generic names
CREATE TEMPORARY TABLE generic AS
-- rxcui, rxaui, str, code
SELECT DISTINCT 
	--r.tty,
	r.rxcui,
	r.rxaui,
	r.code,
	r.str AS "generic_name",
FROM 
	treatment.rxn_conso as r
where 
	r.tty like ('IN')
OR 	
	r.tty LIKE ('MIN');

SELECT *
FROM generic;

SELECT * FROM treatment.rxn_rel rr limit 10;

-- Fifth, create a table that maps brand names to generic names based on the relationships defined in RX Norm documentation
CREATE TEMPORARY TABLE rela as
SELECT DISTINCT 
	b.*,
	g.*,
	r.rela,
	r.rxcui1,
	r.rxcui2 
FROM 
	brand_name AS b
JOIN 
	treatment.rxn_rel AS r 
	ON b.rxcui = r.rxcui2
JOIN 
	generic AS g 
	ON g.rxcui = r.rxcui1
WHERE 
	b.brand_name != g.generic_name
AND
	r.rela LIKE ('has_tradename')
OR 
	r.rela LIKE ('part_of')
OR 
	r.rela LIKE ('reformulated_to');

SELECT *
FROM rela;

create temporary table supress_semantic as
SELECT 
	s.*,
	t.*
from supress as s
inner join
	semantic_type as t
	on t.rxcui = s.rxcui;

select * from supress_semantic;


-- Finally, put it all together!
CREATE TEMPORARY TABLE source_4_staging AS
--create temporary table stmp as
SELECT DISTINCT 
	r.generic_name AS "anchor_drug",
	--r.rxcui1,
	--r.rela,
	--r.rxcui2,
	r.brand_name AS "synonym_name",
	4 AS source_id
	--y.sty
	--t.str,
	--t.tty
FROM 
	supress_semantic as s
INNER JOIN 
	rela AS r 
	-- if the generic in supress, join
	ON r.rxcui1 = s.rxcui;

SELECT DISTINCT count(*)
FROM source_4_staging;

	
