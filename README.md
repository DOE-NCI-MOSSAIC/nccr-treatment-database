# Treatment_Database

## Citation
DOE-NCI-MOSSAIC. (2025). DOE-NCI-MOSSAIC/nccr-treatment-database: NCCR Treatment Database September 2025 Release (treatment-doi-v1). Zenodo. https://doi.org/10.5281/zenodo.17235256

## Data Sources
1 -- HEMOC

2 -- CanMED

3 -- DrugBank

4 -- RX Norm

5 -- NCI Theasurus

6 -- COG Clinical Trial

7 -- SEER RX


## Staging Tables
Drug and regimen specific staging files were created for each dataset.

These dataset specific files create a final drug and regimen staging dataset.

## Production Tables

### Table 1 - Anchor Drugs
anchor_drug_id [pk]

anchor_drug_name

### Table 2 - Anchor Drugs & Synonyms
synonym_id [pk]

anchor_drug_id [fk]

synonym_name

source_id [fk]

### Table 3 - Conditions & Regimens 
condition_id

condition_name

regimen_id [fk]

source_id [fk]

### Table 4 - Data Sources 
source_id [pk]

source_name

source_details

### Table 5 - Anchor Drug Sources
source_id [fk]

anchor_drug_id [fk]

### Table 6 - Anchor Drug to Regimen
regimen_id [fk]

anchor_drug_id [fk]

source_id [fk]

### Table 7 - Regimen Names
regimen_id [pk]

regimen_name

### Table 8 - Regimen Names & Regimen Synonyms
regimen_synonym_id [pk]

regimen_synonym_name

source_id [fk]

regimen_id [fk]

### Table 9 - Regimen Sources
regimen_id [fk]

source_id [fk]

## Execution Order
1) All staging Tables

2) Final Staging Tables

3) Table 4

4) Table 1

5) Table 5

6) Table 2

7) Table 7

8) Table 9

9) Table 6

10) Table 8

11) Table 3
