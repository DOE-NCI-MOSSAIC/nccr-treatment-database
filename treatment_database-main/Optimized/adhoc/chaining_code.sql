

create temporary sequence 

CREATE TEMPORARY TABLE Final_Drug_Staging_Table (
	source_id INT,
	anchor_drug VARCHAR,
	synonym_name VARCHAR
);

-- Insert HemOnc
INSERT INTO Final_Drug_Staging_Table
SELECT DISTINCT
	s1.source_id,
	s1.anchor_drug,
	s1.synonym_name
FROM	
	source_1_staging_drugs as s1;


WITH Uniq AS (
	SELECT DISTINCT anchor_drug
	FROM Final_Drug_Staging_Table
)
INSERT INTO Final_Drug_Staging_Table
SELECT DISTINCT 
	s2.source_id,
	s2.anchor_drug,
	s2.synonym_name
FROM	
	source_2_staging_drugs as s2
WHERE s2.synonym_name NOT IN (
				SELECT DISTINCT anchor_drug 
				FROM Uniq);
				
	
WITH Uniq AS (
	SELECT DISTINCT anchor_drug
	FROM Final_Drug_Staging_Table
)
INSERT INTO Final_Drug_Staging_Table
SELECT DISTINCT 
	s2.source_id,
	s2.synonym_name AS 'anchor_drug',
	s2.anchor_drug AS 'synonmy_name'
FROM	
	source_2_staging_drugs as s2
WHERE s2.synonym_name IN (
				SELECT DISTINCT anchor_drug 
				FROM Uniq);

select count(*) from Final_Drug_Staging_Table;

--select *
--from Final_Drug_Staging_Table
--where anchor_drug like ('mesna') 
--or synonym_name like ('mesna');


		



with 
	table1 AS (
		SELECT DISTINCT 
			*
		FROM 
			Final_Drug_Staging_Table),
 	table2 AS (
		SELECT DISTINCT 
			*
		FROM 
			Final_Drug_Staging_Table) 	
select DISTINCT *
	t1.source_id,
	t1.anchor_drug AS "anchor_drug", -- as "first_anchor",
	t1.synonym_name as "first_syn",
	t2.source_id,
	t2.anchor_drug as "second_anchor",
	t2.synonym_name AS "synonym_name" -- as "second_syn",
from 
	table1 as t1 
join 
	table2 as t2
	on 
		t1.synonym_name = t2.anchor_drug
	where
		t1.anchor_drug != t2.synonym_name; 
	
--exist as an anchor an syn; take the min id as the anchor
-- temp table; pull all syns of the drug in the second anchor drug col  

-- check that within the table there are no other instances of the second anchor not showing up here 
-- then delete from the table where the second anchor t2.row id in this table 	
-- use as a temp table; do these exist in this table 
-- if exist; add them to this table
-- then; delete from anchor drug table where second source row id in this table
-- insert into anchor drug table; select 1, add syn from second_source	
	
	
WITH 
	table1 AS (
		SELECT DISTINCT 
			anchor_drug, --AS 'first_anchor',
			synonym_name, --AS 'first_syn',
			source_id
		FROM 
			Final_Drug_Staging_Table),
 	table2 AS (
		SELECT DISTINCT 
			anchor_drug, --AS 'second_anchor',
			synonym_name, --AS 'second_syn'
			source_id
		FROM 
			Final_Drug_Staging_Table
) 
--INSERT INTO Final_Drug_Staging_Table 
select DISTINCT 
	t2.source_id,
	t1.anchor_drug AS "first_anchor", -- as "first_anchor",
	t1.synonym_name as "first_syn",
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

	
--SELECT DISTINCT 
--	source_id,
--	first_anchor AS "anchor_drug",
--	first_syn AS "synonym_name",
--	--second_syn AS "synonym_name"
--FROM 
--	chaining 
--UNION ALL 
	
INSERT INTO Final_Drug_Staging_Table
SELECT DISTINCT 
	source_id,
	first_anchor AS "anchor_drug",
	second_syn AS "synonym_name"
FROM chaining
WHERE 
	first_syn = second_anchor;

	
DELETE FROM Final_Drug_Staging_Table
WHERE anchor_drug IN (
	SELECT 
		first_syn
	FROM 
		chaining)
AND synonym_name IN (
	SELECT 
		second_anchor
	FROM chaining);	
	
	
	
			