-- This code creates the final staging table for drugs

-- create our shell table
CREATE TEMPORARY TABLE Final_Staging_Table (
	source_id INT,
	anchor_drug VARCHAR,
	synonym_name VARCHAR
);

-- insert hemoc
INSERT INTO Final_Staging_Table
SELECT
	s1.source_id,
	s1.anchor_drug,
	s1.synonym_name
FROM	
	source_1_staging as s1;

SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;

-- insert canmed
INSERT INTO Final_Staging_Table
SELECT
	s2.source_id,
	s2.anchor_drug,
	s2.synonym_name
FROM	
source_2_staging as s2
WHERE 
	NOT EXISTS (
	SELECT fst.anchor_drug
	FROM Final_Staging_Table as fst
	WHERE s2.anchor_drug = fst.synonym_name);

SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;

--insert drugbank
INSERT INTO Final_Staging_Table
SELECT
	s3.source_id,
	s3.anchor_drug,
	s3.synonym_name
FROM	
source_3_staging as s3
WHERE 
	NOT EXISTS (
	SELECT fst.anchor_drug
	FROM Final_Staging_Table as fst
	WHERE s3.anchor_drug = fst.synonym_name);

SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;

--insert rx norm
INSERT INTO Final_Staging_Table
SELECT
	s4.source_id,
	s4.anchor_drug,
	s4.synonym_name 
FROM	
source_4_staging as s4
WHERE 
	NOT EXISTS (
	SELECT fst.anchor_drug
	FROM Final_Staging_Table as fst
	WHERE s4.anchor_drug = fst.synonym_name);


SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;

-- insert nci
INSERT INTO Final_Staging_Table
SELECT
	s5.source_id,
	s5.anchor_drug,
	s5.synonym_name
FROM	
source_5_staging as s5
WHERE 
	NOT EXISTS (
	SELECT fst.anchor_drug
	FROM Final_Staging_Table as fst
	WHERE s5.anchor_drug = fst.synonym_name);

SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;


-- Here, we swap anchors and syns to make sure we do not have overlap in the anchor/syns columns
WITH Temp AS (
	SELECT DISTINCT 
		t1.source_id,
		f.anchor_drug,
		t1.anchor_drug AS "synonym_name"
	FROM Final_Staging_Table as f
		JOIN source_1_staging as t1
		ON f.synonym_name = t1.anchor_drug 
	UNION 
		SELECT DISTINCT 
			t2.source_id,
			f.anchor_drug,
			t2.anchor_drug AS "synonym_name"
		FROM Final_Staging_Table as f
			JOIN source_2_staging as t2
			ON f.synonym_name = t2.anchor_drug 
	UNION 
		SELECT DISTINCT 
			t3.source_id,
			f.anchor_drug,
			t3.anchor_drug AS "synonym_name"
		FROM Final_Staging_Table as f
			JOIN source_3_staging as t3
			ON f.synonym_name = t3.anchor_drug 
	UNION 
		SELECT DISTINCT 
			t4.source_id,
			f.anchor_drug,
			t4.anchor_drug AS "synonym_name"
		FROM Final_Staging_Table as f
			JOIN source_4_staging as t4
			ON f.synonym_name = t4.anchor_drug 
	UNION 
		SELECT DISTINCT 
			t5.source_id,
			f.anchor_drug,
			t5.anchor_drug AS "synonym_name"
		FROM Final_Staging_Table as f
		JOIN source_5_staging as t5
		ON f.synonym_name = t5.anchor_drug 
)	INSERT INTO Final_Staging_Table 
	SELECT *
	FROM Temp;

SELECT DISTINCT COUNT(*)
FROM Final_Staging_Table;


