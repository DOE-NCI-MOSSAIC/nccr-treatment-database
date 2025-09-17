-- Check for anchor/synonym duplicates
--drugs
SELECT count(*)
from source_1_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_2_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_3_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_4_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_5_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_6_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from source_7_staging_drugs
where anchor_drug = synonym_name;

SELECT count(*)
from Final_Drug_Staging_Table
where anchor_drug = synonym_name;

--regimens
SELECT count(*)
from source_1_staging_regimens
where regimen = regimen_synonym;

SELECT count(*)
from source_7_staging_regimens
where regimen = regimen_synonym;

SELECT count(*)
from Final_Regimen_Staging_Table
where regimen = regimen_synonym;


----------------------------------------------------
-- Check for duplicates in every table 

--t1
SELECT count(*)
from Anchor_Drugs
GROUP BY anchor_drug_name 
having count(anchor_drug_name) > 1;

SELECT *
FROM Anchor_Drugs
LIMIT 10;

SELECT count(*)
from Anchor_Drugs
GROUP BY anchor_drug_id
having count(anchor_drug_id) > 1;

--t2 
select count(*)
from syns
group by synonym_id
having count(synonym_id) > 1;

select count(*)
from syns
group by synonym_name
having count(synonym_name) > 1;

SELECT * 
FROM Anchor_Drugs_And_Synonyms
limit 10;
 
--t3 will have duplicates; check the supprting indexs table of regimens
select count(*)
from indexs
group by "condition"
having count("condition") > 1;

select *
FROM Conditions_And_Regimens
limit 10;

--t4; source id table
select * from Data_Sources;

--t5l source table; will have duplicates
select *
from Anchor_Drug_Source;

--t6 will have duplicates; map multiple drugs to one/more regimen
select *
from Anchor_Drugs_To_Regimens;

--t7
select count(*)
from Anchor_Regimen
group by regimen_id
having count(regimen_id) > 1;

select *
from Anchor_Regimen;

--t8
select count(*)
from Regimens_And_Synonyms
group by regimen_synonym_id
having count(regimen_synonym_id) > 1;

--t9 will have duplicates; source table
select *
from Regimen_Source;

--t10 will have duplicates; source table
SELECT *
FROM Anchor_Drug_Synonym_Source;

--------------------------------------------------
--Check that FK map to PK you expect them to 
-- Lets check a drug & regimen

-- get vincristine ex
select *
from Anchor_Drugs
where anchor_drug_name like ('vincristine');

--id == 6079

-- pull syns of vincristine
select *
from Anchor_Drugs_And_Synonyms
where anchor_drug_id = 6079;

-- get chop
select * 
from Anchor_Regimen
where regimen_name like ('chop');

-- id == 489

-- chop syns
select *
from Regimens_And_Synonyms
where regimen_id = 489;

-- check chop for cyclophophamide, doxorubicin, vincristine, prednisone
select *
from Anchor_Drugs_To_Regimens
where regimen_id = 489;

select *
from Anchor_Drugs
where anchor_drug_id in (18499, 156, 6079, 14495);

-------------------------------------------------------
-- Checks on FKs 
-- Use vincristine again

-- t1
--get vincristine id
select *
from Anchor_Drugs
where anchor_drug_name like ('vincristine');

--vincristine id == 3097

-- check oncovin not in this table
select *
from Anchor_Drugs
where anchor_drug_name like ('oncovin');


-- check chop not in this table
select *
from Anchor_Drugs
where anchor_drug_name like ('chop');





-- t2
--  get oncovin (vincristine syn) id; check vincristine syns
select *
from Anchor_Drugs_And_Synonyms
where anchor_drug_id = 6079;

select *
from Anchor_Drugs
where anchor_drug_name like ('oncovin');

-- oncovin id syns == 16661

select *
from Anchor_Drugs_And_Synonyms
where synonym_name like ('oncovin');



--t5 
-- get the sources for vincristine
select * 
FROM Anchor_Drug_Source 
where anchor_drug_id = 6079;





-- t10
-- get oncovin sources
select *
FROM Anchor_Drug_Synonym_Source 
where synonym_id = 16661;



-- t7
-- get chop id
select *
from Anchor_Regimen 
where regimen_name like ('chop');

-- chop id == 489

-- make sure vincristine not in this table
select *
from Anchor_Regimen 
where regimen_name like ('vincristine');

--make sure oncovin not in this table
select *
from Anchor_Regimen 
where regimen_name like ('oncovin');


-- t9 
-- check the sources for chop
select *
from Regimen_Source
where regimen_id = 489;




--t6
-- check that vincristine maps to chop
SELECT *
from Anchor_Drugs_To_Regimens
where anchor_drug_id = 6079;


-- check that cyclophophamide, doxorubicin, vincristine, prednisone map to chop
select * from Anchor_Drugs_To_Regimens 
where regimen_id = 489;



--t8
-- check chop synonyms
select *
from Regimens_And_Synonyms
where regimen_id = 489;



--t3
-- grab chop related cancers
select count(condition_id) from Conditions_And_Regimens;
-- 1040

select *
from Conditions_And_Regimens
where regimen_id = 489;


------------------------------------------------
-- Check the sources for each table

--t1
select DISTINCT count(source_id)
from Anchor_Drugs;

--t2
select DISTINCT count(source_id)
from Anchor_Drugs_And_Synonyms;

--t3
select DISTINCT count(source_id)
from Conditions_And_Regimens;

--t4
select DISTINCT count(source_id)
from Data_Sources;

--t5
select DISTINCT count(source_id)
from Anchor_Drug_Source;

--t6
select DISTINCT count(source_id)
from Anchor_Drugs_To_Regimens;

--t7
select DISTINCT count(source_id)
from Anchor_Regimen;

--t8
select DISTINCT count(source_id)
from Regimens_And_Synonyms;

--t9
select DISTINCT count(source_id)
from Regimen_Source;

--t10
select DISTINCT count(source_id)
from Anchor_Drug_Synonym_Source;




SELECT DISTINCT 
	*
from Final_Drug_Staging_Table
where anchor_drug = ('vinblastine');


select DISTINCT 
	anchor_drug,
	synonym_name
from Final_Drug_Staging_Table
where synonym_name in 
	(SELECT anchor_drug 
	from Final_Drug_Staging_Table);


select *
from Final_Drug_Staging_Table
where anchor_drug = ('vinblastine')
OR synonym_name = ('vinblastine');


select count(*)
from Final_Drug_Staging_Table
group by anchor_drug
having count(anchor_drug) > 1;



