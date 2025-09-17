STAGING TABLES

Tables are numbered in order of priority. Each dataset recieves it's own staging table for drugs and/or regimens. Drugs and regimens are not combined within the staging tables. The following list identifies each dataset, it's priority, and is the legend for naming conventions within the staging and production tables.

1- HEMONC
2- CanMed
3- DrugBank
4- NCI Thearus
5- RX Norm
6- AACT
7- SEER RX

Definitions:
Anchor Drug -- A generic drug name from any dataset.
Anchor Drug Synonym -- A nickname, abbreviation, or brand name of any generic drug.

Anchor Regimen -- A generic regimen name from any dataset.
Anchor Regimen Synonym -- A nickname or abbrevation of any regimen.

------------------------
File: Drug_Combined.SQL

This file creates "anchor drug" and "anchor drug synonym" staging tables for all seven data sources. These tables are "staging" so we only have to call each dataset file once. This streamlines the process for production level tables. Below, we outline the steps needed to recreate each staging table and then combine them into one final drug and synonym staging table.

***
-- Source 1 Staging Table -- HEMONC Data
Temporary Table source_1_staging_drugs (HEMONC)

Get anchor drug names from HEMONC SIGS and Concept_Stage files. Synonym names come from Concept_Synonym_Stage file. We remove duplicates in these files using the "invalid_reason" set to NULL. Invalid reason "D": Deleted. Invalid reason "U": updated/replaced. These duplicates will have unique concept codes; therefore, just using "select distinct" does not remove them. 

Step 1: Get anchor drug (column: concept_name) and anchor drug id (column: concept_code) and remove duplicates with invalid reason filter and grab only drugs using "domain_id = 'DRUG'" from Concept_Stage file using conditional statement.
Step 2: Get synonyms (column: synonym_name) and synonym id (column: synonym_concept_code) and remove duplicates with invalid reason filter from Concept_Synonym_Stage file using conditional statement.
Step 3: Get only anchor drugs and synonyms, assign source.
Step 4: Join Sigs file to both conditional statements using anchor drug and concept code.
Step 5: Remove self references from anchor drugs to synonyms

- SIGS file contains drug names in "component" field. Components are anchor drugs.
- Concept_Stage contains "concept_code" (unique PK) and "concept_name" (unique anchor drug name).
- Concept_Synonym_Stage contains "synonym_concept_code" (FK to concept_code) and "synonym_name" (unique drug synonym name).

"Component" maps to "concept_name" (1:1). Each "concept_name" receives a "concept_code" (1:1). Each "synonym_name" receives a "synonym_concept_code" (1:1). "Synonym_concept_code" maps to "concept_code (many:1)". 

Data download: http://dataverse.harvard.edu/dataset.xhtml?persistentID=doi.10.7910/DVN/FPO4HB
Documentation: HemOnc: a New Standard Vocabulary for Chemotherapy Regimen Representation in the OMOP Common Data Model

***
-- Source 2 Staging Table -- CanMed
Temporary Table source_2_staging_drugs (CanMED)

Step 1: Get anchor names (column: generic_name) and brand names (column: brand_name) from the NDC file and remove self referencing.

Data download: http://seer.cancer.gov/oncologytoolbox/

***
-- Source 3 Staging Table -- DrugBank
Temporary Table source_3_staging_drugs (DrugBank)

Step 1: Get anchor drygs (column: common_name) and unnest the synonyms (column: synonyms) from DrugBank file.
Step 2: Get anchor drugs and synonmys, remove self referencing.

Data download: http://go.drunkbank.com/releases/latest#open-data

***
-- Source 4 Staging Table -- RX Norm
Temporary Table source_4_staging_drugs (RXNorm)

Given the size of RX Norm, we decided to filter the dataset down based on a few steps.
	
Step : We used the suppress flag grab everything set to "N".
Step : We filter Semantic Types to be:
            'Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance'
Because (add logic from Austin)

Data download: Need ULMS Liscense.
Documentation: http://nlm.nih.gov/research/umls/rxnorm/docs/index.html
						
Step : We filter TTY values to differentiate between Brand Names (BN) and Generic Names (IN). We removed any TTY value that included does, formulation, or package size. This leaves: Ingredient (IN), Multiple ingredients (MIN), and Brand Name (BN).
Step : We filter Relationship Values to remove duplicates in the data. 
    Relationships: 
    has_tradename: Map generic names to brand names.
    part_of: Map generic names to combination medications	
    reformulated_to: Map old brand name to new brand name

***
Temp Table source_5_staging_drugs (NCI Thesaurus)
Step 1: Get anchor drugs (column: preferred_name) and synonyms (column: synonyms_and_abbreviations) from NCI Thesaurus file. 
Step 2: We filter Semantic Types to be:
            'Enzyme', 
						'Antibiotics', 
						'Hazardous or Poisonous Substance',
						'Amino Acids, Peptides, and Proteins',
						'Immunologic Factor',
						'Inorganic Chemical',
						'Nucleic Acid, Nucleoside, or Nucleotide',
						'Organic Chemical',
						'Pharmacologic Substance'
Because (add logic from Austin)

Data download: http://ncithesaurus.nci.nih.gov/ncibrowser/

***
Temp Table source_6_staging_drugs (AACT)
Step 1: Get anchor drugs (column: name) from AACT Interventions file.
Step 2: Get synonym names (column: synonym_name) from AACT Interventions Other file.
Step 3: Join id (column: id) in AACT Interventions to AACT Interventions Other (column: intervention_id)
Step 4: Filter Intervention Type in AACT Interventions file by "DRUG" only.

Data Download: http://aact.ctti-clinicaltrials.org/download
Documentation: http://aact.ctti-clinicaltrials.org/schema

Note: Columns that end with _id represent foreign keys. The prefix to the _id suffix is always the singular name of the parent table to which the child is related. These foreign keys always link to the id column of the parents table.
(parent: id in Interventions file; child: interventions_id in Interventions_Other file)

***
Temp Table source_7_staging_drugs (SEER RX)
Get anchor drugs (column: name) and synonyms (column: alternate_name) from SEER RX file. 

Data Download: http://seer.cancer.gov/seertools/seerrx/

------------------------
File: Regimen_Combined.SQL
For all regimen staging tables, we include anchor drug, anchor regimen, and anchor regimen synonyms. This allows for joining tables to be easier later on. 


Temp Table source_1_staging_regimens_and_drugs (HemOnc)
Step 1: Get the anchor regimen (column: regimen) anchor drug associated with that regimen (component) from HemOnc SIGS file. 


***
Temp Table source_7_staging_regimens (SEER RX)
Step 1: Get anchor regimens (column: name) and regimen synonyms (column: alternate_name) from SEER RX Regimens File.
 




