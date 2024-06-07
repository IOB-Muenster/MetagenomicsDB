/* Flexible database for metagenomic patient studies */

/* AUTHOR */

/* Felix Manske, felix.manske@uni-muenster.de */
/* Norbert Grundmann, ngrundma@uni-muenster.de */ 

/* COPYRIGHT */

/* Redistribution and use in source and binary forms, with or without modification, */
/* are permitted provided that the following conditions are met: */

/* 1. Redistributions of source code must retain the above copyright */
/*  notice, this list of conditions and the following disclaimer. */

/* 2. Redistributions in binary form must reproduce the above copyright */
/*  notice, this list of conditions and the following disclaimer in the */
/*  documentation and/or other materials provided with the distribution. */

/* THIS SOFTWARE IS PROVIDED BY THE AUTHOR AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, */
/* INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR */
/* ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES */
/* (INCLUDING, BUT NOT LIMITED TO,  PROCUREMENT  OF  SUBSTITUTE GOODS  OR  SERVICES; */
/* LOSS  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY */
/* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE */
/* OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE */
/* POSSIBILITY OF SUCH DAMAGE. */


/* EXTENSIONS */

CREATE EXTENSION plperl;


/* RELATIONS, FUNCTIONS, AND INDICES */

create table change (
	id serial primary key,
	username varchar(16) not null,
	ts integer not null,
	ip bigint not null
);

create table patient (
	id serial primary key,
	alias varchar(8) not null,
	accession varchar(16) not null,	/* hashed? */
	birthdate date not null,
	id_change integer references change (id) not null,
	unique(alias, accession, birthdate)
);

create table sample (
	id serial primary key,
	id_patient integer references patient(id) not null,
	createdate date not null, /* exact date or rounded? */
	createdby varchar(64),
	iscontrol boolean not null,
	id_change integer references change (id) not null,
	unique (id_patient, createdate, iscontrol)
);


create table type (
	id serial primary key,
	name varchar(64) not null, /* weight, height,... */
	type char(1) not null, /* int, str, date,.. */
	selection varchar[], /* Values for selection box */
	id_change integer references change (id) not null,
	unique(name)
);


create table measurement (
	id serial primary key,
	id_sample integer references sample(id) not null,
	id_type integer references type(id) not null,
	value varchar(64) not null,
	id_change integer references change (id) not null,
	unique (id_sample, id_type)
);

/* Calculate the average error from a quality string in Sanger format */
/* References: */
/* https://labs.epi2me.io/quality-scores/ ; */
/* https://help.nanoporetech.com/en/articles/6629615-where-can-i-find-out-more-about-quality-scores ; */
/* https://doi.org/10.1101/gr.8.3.186 */
CREATE FUNCTION f_calcseqerror (
	IN qual varchar,
	OUT err numeric
)
AS $$
	use strict;
	use warnings;

	my $qual = $_[0];
	return undef if (not $qual);

	my $err = 0;
	foreach my $char (split('', $qual)) {
		my $ascii = ord($char);
		elog(ERROR, 'Invalid quality encoding. Char ->' . $char . '<- is not in range 33-126') if ($ascii > 126 or $ascii < 33);  
		$err += 10 ** (($ascii - 33) / -10)
	}
	$err = $err / length($qual);
	return $err  
$$
LANGUAGE plperl 
	IMMUTABLE
	RETURNS NULL ON NULL INPUT
	PARALLEL SAFE;

create table sequence (
	id serial primary key,
	id_sample integer references sample(id) not null,
	flowcellid varchar(8),
	runid varchar(42) not null,
	barcode varchar(12) not null,
	readid varchar(38) not null,
	callermodel varchar(46),
	nucs varchar(34000) not null,
	quality varchar(34000) not null,
	seqerr numeric generated always as (f_calcseqerror(quality)) stored not null,
	seqlen int generated always as (length(nucs)) stored not null,
	id_change integer references change (id) not null,
	unique (id_sample, runid, barcode, readid)
);

create table taxonomy (
	id serial primary key,
	name varchar(256),
	rank varchar(32) not null,
	id_change integer references change (id) not null
);

/* UNIQUE constraint would consider NULLs as distinct. This index statement treats NULLs as the same. */
create unique index on taxonomy (coalesce(name, ''), rank);

create table classification (
	id serial primary key,
	id_sequence integer references sequence(id) not null,
	program varchar(32) not null,
	database varchar(32) not null,
	id_change integer references change (id) not null,
	unique (id_sequence, program, database)
);

create table taxclass (
	id_taxonomy integer references taxonomy(id),
	id_classification integer references classification(id),
	id_change integer references change(id) not null,
	primary key(id_taxonomy, id_classification)
);

/* WHO growth standards */
create table standard (
	name varchar(36),
	sex varchar(1),
	age smallint,
	l numeric not null,
	m numeric not null,
	s numeric not null,
	id_change integer references change(id) not null,
	primary key (name, sex, age)
);

/* Calculate the z-score for a measurement (value) based on variables (l, m, s) */
/* from the WHO standards. This function assumes that all input is biologically valid. */
/* Reference: https://www.who.int/publications/i/item/924154693X (page 302f) */
CREATE FUNCTION f_calczscore (
	IN l standard.l%TYPE,
	IN m standard.m%TYPE,
	IN s standard.s%TYPE,
	IN value float,
	OUT zscore float
)
LANGUAGE SQL
	IMMUTABLE
	RETURNS NULL ON NULL INPUT
	PARALLEL RESTRICTED
	BEGIN ATOMIC
		WITH zscore_stat as (
			SELECT
				((value / m) ^ l - 1) / (s * l) as z,
				m * (1 + l * s * 3) ^ (1 / l) as sd3pos,
				m * (1 + l * s * -3) ^ (1 / l) as sd3neg,
				m * (1 + l * s * 3) ^ (1 / l) - m * (1 + l * s * 2) ^ (1 / l) as sd23pos,
				m * (1 + l * s * -2) ^ (1 / l) - m * (1 + l * s * -3) ^ (1 / l) as sd23neg
		)
		select CASE
			WHEN z::float >= -3 AND z::float <= 3 THEN round(z::numeric, 2)
			WHEN z::float < -3 THEN round((-3 + (value - sd3neg) / sd23neg)::numeric, 2)
			WHEN z::float > 3 THEN round((3 + (value - sd3pos) / sd23pos)::numeric, 2)
			END zscore
		from zscore_stat;
	END;


/* VIEWS */

/* Display sample data with custom string indicating the timepoint that the sample was taken */
CREATE MATERIALIZED VIEW v_samples AS WITH
	timep (id, id_patient, alias, createdate, timepoint, iscontrol, seqcount) AS (
		SELECT s.id, p.id, p.alias, s.createdate,
			(CASE
				WHEN s.createdate::date - p.birthdate::date BETWEEN 0 AND 1 THEN 'meconium'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 2 AND 4 THEN '3d'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 10 AND 18 THEN '2w'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 35 AND 49 THEN '6w'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 79 AND 101 THEN '3m'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 169 AND 191 THEN '6m'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 259 AND 281 THEN '9m'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 354 AND 376 THEN '1y'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 537 AND 559 THEN '1.5y'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 719 AND 741 THEN '2y'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 902 AND 924 THEN '2.5y'
				WHEN s.createdate::date - p.birthdate::date BETWEEN 1084 AND 1106 THEN '3y'
				ELSE 'NA'
			END) AS timepoint,
			(CASE
				WHEN s.iscontrol THEN 'Yes'
				ELSE 'No'
			END) AS iscontrol,
			(SELECT count(*) FROM sequence WHERE id_sample = s.id) AS seqcount FROM sample s INNER JOIN patient p ON p.id = s.id_patient
	),
	checks (id_patient, timepoint, iscontrol, isok) AS (
		SELECT id_patient, timepoint, iscontrol,
			(CASE
				WHEN timepoint = 'NA' THEN 'f'
				WHEN count(createdate) != 1 THEN 'f'
				ELSE 't'
			END) AS isok FROM timep GROUP BY id_patient, timepoint, iscontrol
	)
	SELECT t.*, c.isok
		FROM timep t INNER JOIN checks c ON c.id_patient = t.id_patient AND c.timepoint = t.timepoint AND c.iscontrol = t.iscontrol;

/* Lineages and counts per sample for export to external web tools */
CREATE MATERIALIZED VIEW v_lineages AS WITH
	smpl (id, samplename) AS (
		SELECT s.id, concat_ws('_', p.alias, vs.timepoint, s.iscontrol) AS samplename FROM patient p INNER JOIN sample s ON s.id_patient = p.id
			INNER JOIN v_samples vs ON vs.id = s.id
	),
	lin (id_sequence, program, database, class) AS (
		SELECT c.id_sequence, c.program, c.database, array_agg(coalesce(t.name, '') ORDER BY
			c.id, array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank))
			FROM classification c INNER JOIN taxclass tc ON tc.id_classification = c.id INNER JOIN taxonomy t ON t.id = tc.id_taxonomy
			GROUP BY c.id
	)
	SELECT s.id, s.samplename, l.program, l.database, l.class, count(*) FROM smpl s
		INNER JOIN sequence seq ON seq.id_sample = s.id INNER JOIN lin l ON l.id_sequence = seq.id GROUP BY s.id, s.samplename, l.program, l.database, l.class;

/* The minimum sequence error will be rated with the maximum quality and vice versa */
CREATE MATERIALIZED VIEW v_taxa AS SELECT
	concat(vs.id, '_', coalesce(c.program, ''), '_', coalesce(c.database, ''), '_', t.id) AS id, p.id AS id_patient,
		vs.id AS id_sample, t.id AS id_taxonomy, p.alias, vs.timepoint, vs.iscontrol,
		c.program, c.database, count(tc.id_taxonomy), t.name, t.rank,
		min(seq.seqlen) AS minlen, round(avg(seq.seqlen), 0) AS avglen, max(seq.seqlen) AS maxlen,
		round((-10*log(max(seq.seqerr))), 0) AS minqual, round((-10*log(avg(seq.seqerr))), 0) AS avgqual, round((-10*log(min(seq.seqerr))), 0) AS maxqual
		FROM patient p
			INNER JOIN v_samples vs ON vs.id_patient = p.id
			INNER JOIN sequence seq ON seq.id_sample = vs.id
			INNER JOIN classification c ON c.id_sequence = seq.id
			INNER JOIN taxclass tc ON tc.id_classification = c.id
			INNER JOIN taxonomy t ON t.id = tc.id_taxonomy
		GROUP BY p.id, vs.id, vs.timepoint, vs.iscontrol, t.id, c.program, c.database;

/* Dollar quoting is more readable while escaping single quotes */
/* Display all measurements in the database and calculate mother's pre-pregnancy BMI (and its category), */
/* difference in body mass at delivery (and its category), mother's age at delivery, and z-score [weight for age] */
/* (and its category and sub-category). */
CREATE MATERIALIZED VIEW v_measurements AS WITH 
	temp (id_patient, accession, birthdate, id, createdate, timepoint, name, type, value) AS (
		SELECT p.id, p.accession, p.birthdate, vs.id, vs.createdate, vs.timepoint,
			t.name, t.type, m.value FROM v_samples vs INNER JOIN measurement m ON m.id_sample = vs.id
			INNER JOIN patient p ON p.id = vs.id_patient INNER JOIN type t ON t.id = m.id_type
	),
	bmi (id_patient, accession, id, createdate, timepoint, name, type, value) AS (
		SELECT t.id_patient, t.accession, t.id, t.createdate, t.timepoint, $$mother's pre-pregnancy BMI$$ AS name, 'i' AS type,
			(round((value::numeric / power((SELECT tmp.value FROM temp tmp WHERE tmp.id = t.id AND tmp.name = $$mother's height$$)::numeric, 2)),2))::text AS value
			FROM temp t WHERE name = 'maternal body mass before pregnancy'
	),
	diffweight (id_patient, accession, id, createdate, timepoint, name, type, value) AS (
		SELECT t.id_patient, t.accession, t.id, t.createdate, t.timepoint, 'difference in body mass at delivery' AS name, 'i' AS type,
			(t.value::numeric - (SELECT tmp.value FROM temp tmp WHERE tmp.id = t.id AND tmp.name = 'maternal body mass before pregnancy')::numeric)::text AS value
			FROM temp t WHERE t.name = 'maternal body mass at delivery'
	),
	sex (id_patient, value) AS (
		SELECT t.id_patient, t.value FROM temp t WHERE t.name = 'sex'
	),
	zscore (id_patient, accession, id, createdate, timepoint, name, type, value) AS (
		SELECT t.id_patient, t.accession, t.id, t.createdate, t.timepoint, 'z-score' AS name, 'i' AS type,
			(SELECT f_calczscore(std.l, std.m, std.s, (t.value::numeric/1000)))::text AS value
			FROM temp t INNER JOIN standard std ON (SELECT sex.value FROM sex WHERE sex.id_patient = t.id_patient) = std.sex AND (t.createdate - t.birthdate) = std.age
			WHERE t.name = 'body mass' AND std.name = 'weight_for_age'
	),
	/* The patient type is defined by the z-score at the first measurement */
	firstzscore (id_patient, createdate, value) AS (
		SELECT DISTINCT ON (z.id_patient) z.id_patient, z.createdate, z.value FROM zscore z ORDER BY z.id_patient, z.createdate asc	
	),
	/* Find first time point where catch-up occurs */
	firstcatchup (id_patient, createdate, timepoint) AS (
		SELECT DISTINCT ON (z.id_patient) z.id_patient, z.createdate, z.timepoint
			FROM zscore z INNER JOIN firstzscore fz ON fz.id_patient = z.id_patient WHERE fz.value::numeric < -2 AND z.value::numeric > -2.0 AND
			abs((SELECT min(xz.value::numeric) FROM zscore xz WHERE xz.id_patient = z.id_patient AND xz.createdate < z.createdate GROUP BY xz.id_patient) - z.value::numeric) >= 0.67
			ORDER BY z.id_patient, z.createdate, z.value ASC
	)
	SELECT id_patient, accession, createdate, timepoint, name, type, value FROM temp
	UNION ALL
	SELECT id_patient, accession, createdate, timepoint, $$mother's age at delivery$$ as name, 'i',
		(round(((birthdate::date - value::date) / 365.25),2))::text as value FROM temp WHERE name = $$mother's birth date$$
	UNION ALL
	SELECT id_patient, accession, createdate, timepoint, name, type, value FROM bmi
	UNION ALL
	SELECT id_patient, accession, createdate, timepoint, $$mother's pre-pregnancy BMI category$$, 's',
		CASE
			WHEN value::float < 18.5 THEN 'underweight'
			WHEN value::float >= 18.5 AND value::float < 25.0 THEN 'normal weight'
			WHEN value::float >= 25.0 AND value::float < 30.0 THEN 'overweight'
			WHEN value::float >= 30.0 THEN 'obesity'
		END value
		FROM bmi
	UNION ALL	
	SELECT id_patient, accession, createdate, timepoint, name, type, value FROM diffweight
	UNION ALL
	SELECT bmi.id_patient, bmi.accession, bmi.createdate, bmi.timepoint, $$category of difference in body mass at delivery$$, 's',
		CASE
			WHEN bmi.value::float < 18.5 AND dw.value::float < 12.5 THEN 'not enough'
			WHEN bmi.value::float < 18.5 AND dw.value::float >= 12.5 AND dw.value::float <= 18.0 THEN 'appropriate'
			WHEN bmi.value::float < 18.5 AND dw.value::float > 18.0 THEN 'too much'
			WHEN bmi.value::float >= 18.5 AND bmi.value::float < 25.0 AND dw.value::float < 11.5 THEN 'not enough'
			WHEN bmi.value::float >= 18.5 AND bmi.value::float < 25.0 AND dw.value::float >= 11.5 AND dw.value::float <= 16.0 THEN 'appropriate'
			WHEN bmi.value::float >= 18.5 AND bmi.value::float < 25.0 AND dw.value::float > 16.0 THEN 'too much'
			WHEN bmi.value::float >= 25.0 AND bmi.value::float < 30 AND dw.value::float < 7.0 THEN 'not enough'
			WHEN bmi.value::float >= 25.0 AND bmi.value::float < 30 AND dw.value::float >= 7.0 AND dw.value::float <= 11.5 THEN 'appropriate'
			WHEN bmi.value::float >= 25.0 AND bmi.value::float < 30 AND dw.value::float > 11.5 THEN 'too much'
			WHEN bmi.value::float >= 30.0 AND dw.value::float < 5.0 THEN 'not enough'
			WHEN bmi.value::float >= 30.0 AND dw.value::float >= 5.0 AND dw.value::float <= 9.0 THEN 'appropriate'
			WHEN bmi.value::float >= 30.0 AND dw.value::float > 9.0 THEN 'too much'
		END value
		FROM bmi INNER JOIN diffweight dw ON bmi.id = dw.id
	UNION ALL	
	SELECT id_patient, accession, createdate, timepoint, name, type, value FROM zscore
	UNION ALL
	SELECT z.id_patient, z.accession, z.createdate, z.timepoint, 'z-score category', 's',
		CASE
			/* Child born average is always AGA */
			WHEN fz.value::numeric >= -2.0 THEN 'AGA'
			/* Child born too small is category SGA */
			WHEN fz.value::numeric < -2.0 THEN 'SGA'	
			ELSE NULL
		END value
		FROM zscore z INNER JOIN firstzscore fz ON fz.id_patient = z.id_patient
	UNION ALL
	SELECT z.id_patient, z.accession, z.createdate, z.timepoint, 'z-score subcategory', 's',
		CASE
			/* Child born average is always AGA */
			WHEN fz.value::numeric >= -2.0 THEN 'AGA'
			/* Child born too small is SGA at meconium */
			WHEN fz.value::numeric < -2.0 AND fz.createdate = z.createdate THEN 'SGA'
			/* Child born too small that never catches up */
			WHEN fz.value::numeric < -2.0 AND fz.createdate != z.createdate AND fc.timepoint IS NULL THEN 'no catch-up'
			/* Child born too small that eventually catches up. Current timepoint before earliest catch-up point */
			WHEN fz.value::numeric < -2.0 AND fz.createdate != z.createdate AND fc.timepoint IS NOT NULL AND fc.createdate > z.createdate THEN 'no catch-up'
			/* Child born too small that eventually catches up. Current timepoint at or after earliest catch-up point. Earliest catch-up point at most 6 month => early catch-up */
			WHEN fz.value::numeric < -2.0 AND fz.createdate != z.createdate AND fc.timepoint IS NOT NULL AND fc.createdate <= z.createdate AND
				fc.timepoint in ('meconium', '3d', '2w', '6w', '3m', '6m') THEN 'early catch-up'			
			/* Child born too small that eventually catches up. Current timepoint at or after earliest catch-up point. Earliest catch-up point after 6 month => late catch-up */			
			WHEN fz.value::numeric < -2.0 AND fz.createdate != z.createdate AND fc.timepoint IS NOT NULL AND fc.createdate <= z.createdate AND
				fc.timepoint in ('9m', '1y', '1.5y', '2y', '2.5y', '3y') THEN 'late catch-up'		
			ELSE NULL
		END value
		FROM zscore z INNER JOIN firstzscore fz ON fz.id_patient = z.id_patient LEFT OUTER JOIN firstcatchup fc ON fc.id_patient = z.id_patient;


/* Compared to v_measurements, this view makes the static measurements */
/* (incl. selected measurements derived from statics) available for all createdates of a patient. */
/* In v_measurements, these are only reported for the first createdate of an individual patient. */
/* firstdate: The first createdate for each patient */
/* firstmeta: The static metadata from the first createdate of each patient => later added to all createdates */
/* createdate: All createdates for all patients */
/* newmeasures: Add measures for program, database, and timepoint to each createdate */
CREATE MATERIALIZED view v_metadata AS WITH
	firstdate (id_patient, createdate) AS (
		SELECT vm.id_patient, min(vm.createdate) FROM v_measurements vm GROUP BY id_patient
	),
	firstmeta (id_patient, name, type, value) AS (
		SELECT vm.id_patient, vm.name, vm.type, vm.value FROM v_measurements vm
			INNER JOIN firstdate fd ON fd.id_patient = vm.id_patient AND fd.createdate = vm.createdate
			WHERE vm.name IN ('sex', 'birth mode', $$mother's age at delivery$$, $$mother's pre-pregnancy BMI category$$,
			'category of difference in body mass at delivery', 'pregnancy order', 'maternal illness during pregnancy',
			'maternal antibiotics during pregnancy')
	),
	createdate (samplename, id_patient, id_sample, createdate) AS (
		SELECT CONCAT_WS('_', p.alias, (select timepoint from v_samples vs where vs.id = s.id), 'f') as samplename, vm.id_patient, s.id, vm.createdate FROM
			v_measurements vm INNER JOIN patient p ON p.id = vm.id_patient INNER JOIN sample s ON s.id_patient = vm.id_patient AND s.createdate = vm.createdate AND
			s.iscontrol = 'f' GROUP BY samplename, vm.id_patient, s.id, vm.createdate
	),
	newmeasures (samplename, id_sample, name, type, value) AS (
		SELECT cd.samplename, cd.id_sample, 'program' AS name, 's' AS type, vl.program AS value
			FROM createdate cd INNER JOIN v_lineages vl ON vl.id = cd.id_sample
		UNION DISTINCT
		SELECT cd.samplename, cd.id_sample, 'database' AS name, 's' AS type, vl.database AS value
			FROM createdate cd INNER JOIN v_lineages vl ON vl.id = cd.id_sample
		UNION DISTINCT
		SELECT cd.samplename, cd.id_sample, 'timepoint' AS name, 's' AS type, vm.timepoint AS value
			FROM createdate cd INNER JOIN v_measurements vm ON vm.id_patient = cd.id_patient and vm.createdate = cd.createdate
	)
	SELECT CONCAT_WS('_', p.alias, (select timepoint from v_samples vs where vs.id = s.id), 'f') as samplename, s.id as id_sample, vm.name, vm.type, vm.value
		FROM v_measurements vm INNER JOIN patient p ON p.id = vm.id_patient INNER JOIN sample s ON s.id_patient = vm.id_patient AND s.createdate = vm.createdate AND s.iscontrol = 'f'
	UNION DISTINCT
	SELECT cd.samplename, cd.id_sample, fm.name, fm.type, fm.value FROM createdate cd INNER JOIN
		firstmeta fm ON fm.id_patient = cd.id_patient
	UNION DISTINCT
	SELECT * FROM newmeasures;

