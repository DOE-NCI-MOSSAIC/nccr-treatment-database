-- code base for table 6: anchor drugs to regimens

-- create our shell table
CREATE TEMPORARY TABLE Anchor_Drugs_To_Regimens (
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
	Regimen_Name as r
left join 
	Final_Regimen_Staging_Table as s
	on r.regimen_name = s.regimen
left join 
	Anchor_Drugs as a 
	on a.anchor_drug_name = s.anchor_drug;

SELECT * from Final_Regimen_Staging_Table;

	