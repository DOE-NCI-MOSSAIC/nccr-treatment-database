-- Code base for Table 4 to create Datasource


CREATE TEMPORARY TABLE source_mapping (
	source_id INTEGER,
	dataset_name VARCHAR,
	dataset_description VARCHAR
);

INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (1, 'HEMOC', 'Datasource Link: hemoc.org/wiki/Main_page 
						HEMOC is the largest freely available medical wiki of interventions, regimens, and general information relevant to hematology and oncology.');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (2, 'CanMED', 'CanMed Linl: seer.cancer.gov/oncologytoolbox
						The Cancer Medications Enquiry Database (CanMED) is a two-part resource for cancer drug treatment studies. It uses National Drug Code (NDC) and Healthcare Common Prodecure Coding System (HCPCS)');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (3, 'Drug Bank', 'DrugBank Link: go.drugbank.com/releases/latest#open-data
							DrugBank identifiers, names and synonyms permit easy linkage into projects');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (4, 'NCI Thesaurus', 'NCI Thesaurus Link: evs.nci.nih.gov/ftp1/NCI_Thesaurus
								The Enterprise Vocabulary Services provides terminology content, tools, and services to meet the needs of the NCI and biomedical resaerch community.');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (5, 'RXNorm', 'RXNorm Link: nlm.nih.gov/research/umls/rxnorm/index.html 
						RxNorm provides normalized names of clinical drugs and links 
						its names to many of the drug vocabularies commonly used in pharmacy 
						management and drug interaction software, including First Databank, 
						Micromedex, Multum, and Gold Standard Drug Database');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (6, 'COG Clincial Trial', 'COG DATAFILES');
INSERT INTO source_mapping (source_id, dataset_name, dataset_description) 
	VALUES (7, 'SEER*RX', 'SEER*RX Link: seer.cancer.gov/tools/seerrx 
						SEER*RX was developed as a one-step lookup for coding oncology drug and regimen treatmet categories in cancer registries.');



CREATE TEMPORARY TABLE Data_Sources as
SELECT DISTINCT 
	s.source_id,
	s.dataset_name,
	s.dataset_description
FROM  
	source_mapping as s;
	

--ALTER TABLE Data_Sources ADD CONSTRAINT Data_Sources_PK PRIMARY KEY (source_id);
