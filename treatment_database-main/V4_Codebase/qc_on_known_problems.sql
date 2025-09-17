select * from Anchor_Drugs
where anchor_drug_name like ('vincristine');
--id = 2853

select * from Anchor_Drugs
where anchor_drug_name like ('vincasar');
--should be null

select * from Anchor_Drugs
where anchor_drug_name like ('oncovin');
--should be null

select * from Anchor_Drugs
where anchor_drug_name like ('vinblastine');
--id 2394
-- should not be syn of vincristine; 
--showing as anchor is good first check

select * from Anchor_Drugs_And_Synonyms
where anchor_drug_id = 2853;
--find the syns of vincrstine
--skim the list, ensure oncovin & vincasar are there
--ensure vinblastine isnt

SELECT * FROM Anchor_Drugs_And_Synonyms
WHERE synonym_name = ('vincristine');
--confirm that vincristine isnt a syn

SELECT * FROM Anchor_Regimen
WHERE regimen_name LIKE ('chop%');
--chop id = 293

SELECT * FROM Anchor_Drug_Source 
WHERE anchor_drug_id = 2853;
--vincrisitne in multple sources

SELECT * from Anchor_Drugs_To_Regimens
WHERE regimen_id = 293;
--find out what drugs are in chop
--id 134, 12671, 2853, 15487
--we are looking for cyclophosphamide, doxorubicin, vincristine, prednisone
--from seerrx & austin

SELECT * FROM Anchor_Drugs
WHERE anchor_drug_id IN ('134', '12671', '2853', '15487');
--in order
--predinose, cyclophosphamide, vincristine, doxorubicin

select *
from Anchor_Drugs
where anchor_drug_name = 'vinblastine';
--id 2394

select *
from Anchor_Drugs_And_Synonyms
where anchor_drug_id = 2394;
--make sure vinblastine is its own drug
-- we see that it is



