-- Create Datasource Table
CREATE TEMPORARY TABLE source_mapping (
	source_id INTEGER,
	dataset_name VARCHAR,
	dataset_link VARCHAR,
	dataset_description VARCHAR
);

INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES  (1, 'HEMOC', 'Datasource Link: hemoc.org/wiki/Main_page', 'HEMOC is the largest freely available medical wiki of interventions, regimens, and general information relevant to hematology and oncology.');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (2, 'CanMED', 'CanMed Linl: seer.cancer.gov/oncologytoolbox', 'The Cancer Medications Enquiry Database (CanMED) is a two-part resource for cancer drug treatment studies. It uses National Drug Code (NDC) and Healthcare Common Prodecure Coding System (HCPCS)');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (3, 'Drug Bank', 'DrugBank Link: go.drugbank.com/releases/latest#open-data', 'DrugBank identifiers, names and synonyms permit easy linkage into projects');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (4, 'NCI Thesaurus', 'NCI Thesaurus Link: evs.nci.nih.gov/ftp1/NCI_Thesaurus', 'The Enterprise Vocabulary Services provides terminology content, tools, and services to meet the needs of the NCI and biomedical resaerch community.');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (5, 'RXNorm', 'RXNorm Link: nlm.nih.gov/research/umls/rxnorm/index.html', 'RxNorm provides normalized names of clinical drugs and links its names to many of the drug vocabularies commonly used in pharmacy management and drug interaction software, including First Databank, Micromedex, Multum, and Gold Standard Drug Database');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (6, 'AACT Clincial Trial', 'AACT Link: aact.ctti-clinicaltrials.org/download', 'AACT DATAFILES');
INSERT INTO source_mapping (source_id, dataset_name, dataset_link, dataset_description) 
	VALUES (7, 'SEER*RX', 'SEER*RX Link: seer.cancer.gov/tools/seerrx', 'SEER*RX was developed as a one-step lookup for coding oncology drug and regimen treatmet categories in cancer registries.');
					
-- Create the Table
CREATE  TABLE Data_Sources as
SELECT DISTINCT 
	s.source_id,
	s.dataset_name,
	s.dataset_link,
	s.dataset_description
FROM  
	source_mapping as s;

--ALTER TABLE Data_Sources ADD CONSTRAINT Data_Sources_PK PRIMARY KEY (source_id);






-- Table 1: Anchor drug id  and anchor drug names
-- create auto index
CREATE TEMPORARY SEQUENCE anchor_drug_id START 1;

-- create shell table
CREATE  TABLE Anchor_Drugs (
	anchor_drug_id INTEGER PRIMARY KEY,
	anchor_drug_name VARCHAR
);

-- Grab what we need from the drug staging table
INSERT INTO Anchor_Drugs
WITH x as (
	select DISTINCT 
		anchor_drug as "anchor_drug_name"
	from 
		Drug_Staging_Table 
) SELECT 
	nextval('anchor_drug_id') as anchor_drug_id,
	x.*
FROM x;








-- Table 5: Anchor Drug Sources
CREATE  TABLE Anchor_Drug_Source AS
SELECT DISTINCT 
	f.source_id,
	a.anchor_drug_id
FROM 
	Drug_Staging_Table as f
JOIN 
	Anchor_Drugs as a
	ON a.anchor_drug_name = f.anchor_drug;

--ALTER TABLE Anchor_Drug_Source ADD CONSTRAINT Anchor_Drug_Source_Anchor_Drugs_FK FOREIGN KEY (anchor_drug_id) REFERENCES Anchor_Drugs(anchor_drug_id);
--ALTER TABLE Anchor_Drug_Source ADD CONSTRAINT Anchor_Drug_Source_Data_Sources_FK FOREIGN KEY (source_id) REFERENCES Data_Sources(source_id);







-- Table 2: Anchor Drug & Synonyms Table.
-- Create auto index
CREATE TEMPORARY SEQUENCE synonym_id START 1;

CREATE TEMPORARY TABLE syns AS
WITH x AS (
	SELECT DISTINCT 
		synonym_name
	FROM
		Drug_Staging_Table
	WHERE 
		synonym_name NOT LIKE ('none')
	OR 
		synonym_name NOT NULL 
) SELECT 
	x.*,
	nextval('synonym_id') AS synonym_id
FROM x;


-- Create shell table
CREATE  TABLE Anchor_Drugs_And_Synonyms (
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
JOIN Drug_Staging_Table AS f 
 ON s.synonym_name = f.synonym_name
JOIN Anchor_Drugs AS a 
	ON a.anchor_drug_name = f.anchor_drug
where 
	s.synonym_name not like ('none');





-- Table 10: Anchor Drug Sources
CREATE  TABLE Anchor_Drug_Synonym_Source AS
SELECT DISTINCT 
	f.source_id,
	a.synonym_id
FROM 
	Drug_Staging_Table as f
JOIN 
	Anchor_Drugs_And_Synonyms as a
	ON a.synonym_name = f.synonym_name;






-- Table 7: Regimen name and ID
-- create auto index
CREATE TEMPORARY SEQUENCE regimen_id START 1;

-- create shell table
CREATE  TABLE Anchor_Regimen (
	regimen_id INTEGER PRIMARY KEY,
	regimen_name VARCHAR
);

-- Insert from staging table
INSERT INTO Anchor_Regimen
WITH x as (
	SELECT DISTINCT 
		regimen_name as "regimen_name"
	FROM 
		Regimen_Staging_Table
) SELECT
	nextval('regimen_id') as regimen_id,
	x.*
FROM x;





-- Table 9: Regimen ID and Regimen Souce
--create shell table
CREATE  TABLE Regimen_Source (
	regimen_id INT,
	source_id INT
);

-- Insert from staging table & regimen name table
INSERT INTO Regimen_Source
SELECT 
	n.regimen_id,
	r.source_id
from 
	Anchor_Regimen as n
join 
	Regimen_Staging_Table as r
	on r.regimen_name = n.regimen_name;

	
-- Table 6: anchor drugs to regimens
-- Create shell table
CREATE  TABLE Anchor_Drugs_To_Regimens (
	regimen_id INT,
	anchor_drug_id INT,
	source_id INT
);


INSERT INTO Anchor_Drugs_To_Regimens
SELECT DISTINCT 
	r.regimen_id,
	a.anchor_drug_id,
	s.source_id
FROM 
	Anchor_Regimen as r
left join 
	Regimen_Staging_Table as s
	on r.regimen_name = s.regimen_name
left join 
	Anchor_Drugs as a 
	on a.anchor_drug_name = s.anchor_drug;



-- new one edit me



-- Table 8: regimen and regimen synonyms
-- create auto indexing
CREATE TEMPORARY SEQUENCE regimen_synonym_id START 1;

CREATE TEMPORARY TABLE regimen_syns AS
WITH x AS (
	SELECT DISTINCT 
		regimen_synonym
	FROM
		Regimen_Staging_Table
	WHERE 
		regimen_synonym NOT LIKE ('none')
	OR 
		regimen_synonym NOT NULL 
) SELECT 
	x.*,
	nextval('regimen_synonym_id') AS regimen_synonym_id
FROM x;

-- Create shell table
CREATE  TABLE Regimens_And_Synonyms (
	regimen_synonym_id INT,
	regimen_synonym VARCHAR,
	source_id INT,
	regimen_id INT
);

-- insert from staging table
INSERT INTO Regimens_And_Synonyms
SELECT DISTINCT 
	rs.regimen_synonym_id,
	rs.regimen_synonym,
	f.source_id,
	r.regimen_id
FROM regimen_syns AS rs
JOIN Regimen_Staging_Table AS f
	ON f.regimen_synonym = rs.regimen_synonym
JOIN Anchor_Regimen AS r 
	ON r.regimen_name = f.regimen_name;


-- Table 3: Regimens and Conditions
-- create auto indexing
CREATE TEMPORARY SEQUENCE condition_id START 1;

--create shell table
CREATE  TABLE Conditions_And_Regimens (
	condition_id INT,
	condition_name VARCHAR,
	regimen_id INT,
	source_id INT
);


--INSERT INTO Conditions_And_Regimens
CREATE TEMPORARY TABLE indexs AS
WITH x AS (
	SELECT DISTINCT 
		lower(h."condition") as "condition",
		1 as source_id,
	FROM
		TREATMENT.SRC_HEMONC_POINTER AS h
) SELECT 
	x.*,
	nextval('condition_id') AS condition_id
FROM x;
	

INSERT INTO Conditions_And_Regimens
SELECT DISTINCT 
	i.condition_id,
	i."condition",
	r.regimen_id,
	i.source_id
FROM indexs AS i
JOIN TREATMENT.SRC_HEMONC_POINTER AS h 
	ON lower(h."condition") = lower(i."condition")
JOIN Anchor_Regimen AS r 
	ON lower(r.regimen_name) = lower(h.regimen)
	WHERE i.source_id LIKE ('1');



-- Source 6 Staging Table (AACT)
CREATE TEMPORARY SEQUENCE row_id start 1;

CREATE  TABLE Clinical_Trials AS
with X as (
	SELECT DISTINCT 
		a.id as "interventions_id",
		a.nct_id as "clinical_trial_id",
		a.name as "name",
		o.name as "other_name",
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
		lower(a.name) != lower(o.name)
) select 
	nextval('row_id') as row_id,
	X.*
from X;


--------------COMPOSITE DRUGS---------------------------------
--IDs NEED TO BE UPDATED TO FINAL
--CUIs WERENT PULLED ALL THE WAY THROUGH SO IGNORING FOR NOW

CREATE  TABLE Composite_Anchor_ID AS
SELECT anchor_drug_id
FROM anchor_drugs
WHERE anchor_Drug_name IN 
	(SELECT anchor_drug 
	FROM compositedrug);

CREATE TEMPORARY TABLE CompDrugInsert AS
SELECT a.anchor_Drug_id,
	a.anchor_drug_name, 
	asy.synonym_id,
	asy.synonym_name,
	ads.source_id
FROM Composite_Anchor_ID AS c
LEFT OUTER JOIN Anchor_Drugs_And_Synonyms AS asy
	LEFT OUTER JOIN Anchor_Drug_Synonym_Source as ads
	ON asy.synonym_id = ads.synonym_id
ON c.anchor_drug_id =asy.anchor_drug_id
	JOIN Anchor_Drugs AS a
	ON c.anchor_drug_id = a.anchor_drug_id;

SELECT max(anchor_drug_id)
FROM Anchor_drugs;
--22804

select max(synonym_id)
from Anchor_drugs_and_synonyms;
--57087

CREATE TEMPORARY SEQUENCE CompID start 57088;

INSERT INTO CompDrugInsert
SELECT nextval('CompID') as "Anchor_Id",
	anchor_drug as "anchor_drug_name", 
	nextval('CompID') as "synonym_id",
	synonym_name,
	source_id
FROM compositedrug
WHERE anchor_drug NOT IN 
	(SELECT anchor_drug_name 
	 FROM CompDrugInsert)
ORDER BY anchor_id;
--4523

UPDATE CompDrugInsert
SET synonym_id = NULL 
WHERE Anchor_drug_id IN 
	(SELECT anchor_drug_id 
	FROM CompDrugInsert 
	WHERE synonym_name IS NULL);
--4478


DELETE
FROM Anchor_Drugs_And_Synonyms
WHERE anchor_Drug_id IN 
	(SELECT anchor_drug_id FROM CompDrugInsert);
--1146

SELECT Max(synonym_id)
FROM CompDrugInsert;
--59054
SELECT max(Anchor_drug_id)
FROM CompDrugInsert;
--65455

CREATE TEMPORARY SEQUENCE CompID2 start 65456;

CREATE  TABLE Composite_Drug_Component AS
SELECT DISTINCT cd.anchor_drug_id,
	c.anchor_drug as "anchor_drug_name",
	c.component_drug as "component_drug_name",
	nextval('CompID2') as "component_Drug_id",
	c.source_id
FROM Composite_drug_components as c
	JOIN CompDrugInsert as cd
	ON c.anchor_drug = cd.anchor_drug_name
WHERE cd.source_id = 4;

INSERT INTO Anchor_Drugs
SELECT DISTINCT anchor_drug_id,
anchor_drug_name
FROM CompDrugInsert
WHERE anchor_drug_id NOT IN (
			SELECT anchor_drug_id
			FROM Anchor_Drugs);

CREATE  TABLE Composite_Drugs AS	
SELECT DISTINCT *
FROM CompDrugInsert;

--Create minumum id and insert back into anchor_Drugs
CREATE TEMPORARY TABLE Lookup as
SELECT min(anchor_drug_id) as New_anchor_drug_id,anchor_drug_name
FROM composite_drugs
GROUP BY anchor_drug_name;

CREATE TEMPORARY TABLE Lookup2 as
SELECT l.*,c.anchor_drug_id
FROM Lookup as l
	JOIN composite_drugs as c
	ON l.anchor_drug_name = c.anchor_drug_name
WHere l.New_anchor_drug_id != c.anchor_drug_id;

DELETE 
FROM Anchor_Drugs
WHERE anchor_drug_id IN (
			SELECT anchor_drug_id
			FROM Lookup2);

UPDATE composite_drugs
SET anchor_drug_id = t.anchor_drug_id
FROM (select l.anchor_drug_name,l.anchor_drug_id
	FROM composite_drugs as c
	JOIN Anchor_Drugs as l
	on c.anchor_drug_name = l.anchor_drug_name) as t
WHERE composite_drugs.anchor_drug_name = t.anchor_drug_name
	


