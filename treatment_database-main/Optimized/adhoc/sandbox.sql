-- Table 2: Anchor Drug & Synonyms Table.
-- Create auto index
CREATE TEMPORARY SEQUENCE synonym_id START 1;

CREATE TEMPORARY TABLE syns AS
WITH x AS (
	SELECT DISTINCT 
		synonym_name
	FROM
		Final_Drug_Staging_Table
	WHERE 
		synonym_name NOT LIKE ('none')
	OR 
		synonym_name NOT NULL 
) SELECT 
	x.*,
	nextval('synonym_id') AS synonym_id
FROM x;


-- Create shell table
CREATE TEMPORARY TABLE Anchor_Drugs_And_Synonyms (
	synonym_id INT,
	anchor_drug_id INT,
	synonym_name VARCHAR,
);

-- Grab what we need from the anchor drug table and staging table
INSERT INTO Anchor_Drugs_And_Synonyms
SELECT DISTINCT 
	s.synonym_id,
	a.anchor_drug_id,
	s.synonym_name
FROM syns AS s
JOIN Final_Drug_Staging_Table AS f 
 ON s.synonym_name = f.synonym_name
JOIN Anchor_Drugs AS a 
	ON a.anchor_drug_name = f.anchor_drug
where 
	s.synonym_name not like ('none');


select * FROM Anchor_Regimen;
SELECT * FROM Regimens_And_Synonyms;

SELECT * FROM regimen_syns;
SELECT * FROM Final_Regimen_Staging_Table
WHERE regimen = 'kcd';


drop table Regimens_And_Synonyms;
drop table regimen_syns;
drop sequence regimen_synonym_id;


SELECT *
FROM Anchor_Regi





-- check canmed for circular refereneces 	
CREATE TEMPORARY TABLE source_2_staging_drugs_cross AS 
SELECT DISTINCT 
	f2.anchor_drug,
	f2.synonym_name,
	f2.source_id
FROM 
	source_2_staging_drugs AS f1
JOIN 
	source_2_staging_drugs AS f2
	ON
		f1.anchor_drug = f2.synonym_name
	AND 
		f1.synonym_name = f2.anchor_drug;
	
-- delete the swaps from the canmed dataset	
DELETE FROM source_2_staging_drugs
WHERE anchor_drug IN ( 
	SELECT 
		anchor_drug 
	FROM 
		source_2_staging_drugs_cross)
AND 
	synonym_name IN (
	SELECT 
		synonym_name
	FROM 
		source_2_staging_drugs_cross);


CREATE TEMPORARY TABLE source_1_staging_drugs AS 
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
		
	
	
	
	
	
SELECT count(*) from TREATMENT.SRC_AACT_INTERVENTIONS_OTHER saio;
--421228

SELECT 
	count(*)
FROM 
	TREATMENT.SRC_AACT_INTERVENTIONS as a
right JOIN 
	TREATMENT.SRC_AACT_INTERVENTIONS_OTHER as o
	on 
		a.name = o.name;
	
	
--where 
--	a.intervention_type like ('DRUG');
--and 
--	lower(a.name) != lower(o.name);
	
	
create temporary table aact_filtered_version as 
select DISTINCT 
	id, 
	name,
	intervention_type
from 
	TREATMENT.SRC_AACT_INTERVENTIONS sai;



create temporary table aact_namedType as 
select DISTINCT 
	name,
	intervention_type
from 
	TREATMENT.SRC_AACT_INTERVENTIONS sai;
	

create temporary table aact_filteredsyns as 
select DISTINCT 
	o.id,
	o.intervention_id,
	nt.name
from 
	TREATMENT.SRC_AACT_INTERVENTIONS_OTHER o
join 
	aact_namedType as nt
	on o.name = nt.name
WHERE 
	nt.intervention_type  = 'DRUG';
--116703 with id




select count(*) from aact_namedType
--462736


select count(*) from TREATMENT.SRC_AACT_INTERVENTIONS sai;
--848694

select * from aact_filtered_version where name like ('vincristine');
	
	
select 
	first_anchor as "anchor_drug",
	second_syn as "second_syn"
from chains
limit 50;


--35983	
SELECT DISTINCT 
	lower(a.name) as "anchor_drug",
	lower(o.name) as "synonym_name",
	6 as source_id
FROM 
	aact_filtered_version as a
JOIN 
	aact_filteredsyns as o
	on 
		a.id = o.intervention_id 
where 
	a.intervention_type like ('DRUG')
and 
	lower(a.name) != lower(o.name)
AND
	lower(o.name) LIKE ('vincristine');
--OR 
--	lower(o.name) LIKE ('vincristine');
--	
	
	




	
	
	
	
SELECT DISTINCT count(name) from treatment.SRC_AACT_INTERVENTIONS;
	
	
SELECT DISTINCT count(name) from treatment.SRC_AACT_INTERVENTIONS_OTHER;

	

SELECT * FROM Final_Drug_Staging_Table
WHERE anchor_drug LIKE ('mesna')
OR synonym_name LIKE ('mesna');
	
	
SELECT * FROM source_2_staging_drugs_cross
WHERE anchor_drug LIKE ('mesna');
	
SELECT * FROM Final_Drug_Staging_Table 
WHERE anchor_drug LIKE ('abiraterone acetate')
OR synonym_name LIKE ('abiraterone acetate')
LIMIT 10;

SELECT 
	*
FROM 
	Final_Drug_Staging_Table
JOIN 
	
	




DELETE FROM Final_Drug_Staging_Table
WHERE anchor_drug IN (
	SELECT 
		second_anchor
	FROM chains)
AND synonym_name IN (
	SELECT 
		second_syn
	FROM chains);
	
INSERT INTO Final_Drug_Staging_Table
SELECT DISTINCT 
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name"
FROM chains
	WHERE first_anchor != second_syn;


DROP TABLE source_2_swaps;
DROP TABLE Final_Drug_Staging_Table;


SELECT * FROM source_2_swaps;

SELECT * FROM Final_Drug_Staging_Table
WHERE anchor_drug = 'mesna'
OR synonym_name = 'mesna';











	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	






































