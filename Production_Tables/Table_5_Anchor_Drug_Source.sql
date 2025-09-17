-- code for Table 5: anchor drug sources

-- this table will be made from the anchor drug table and staging table
-- grab sources and ids 
CREATE TEMPORARY TABLE Anchor_Drug_Source AS
SELECT DISTINCT 
	f.source_id,
	a.anchor_drug_id
FROM 
	Final_Staging_Table as f
JOIN 
	Anchor_Drugs as a
	ON a.anchor_drug_name = f.anchor_drug;
	

SELECT count(*) from Anchor_Drug_Source as a;

--ALTER TABLE Anchor_Drug_Source ADD CONSTRAINT Anchor_Drug_Source_Anchor_Drugs_FK FOREIGN KEY (anchor_drug_id) REFERENCES Anchor_Drugs(anchor_drug_id);
--ALTER TABLE Anchor_Drug_Source ADD CONSTRAINT Anchor_Drug_Source_Data_Sources_FK FOREIGN KEY (source_id) REFERENCES Data_Sources(source_id);
