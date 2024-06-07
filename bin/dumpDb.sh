#!/usr/bin/env bash


# AUTHOR

# Felix Manske, felix.manske@uni-muenster.de


# COPYRIGHT

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO,  PROCUREMENT  OF  SUBSTITUTE GOODS  OR  SERVICES;
# LOSS  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


#==================================================================================================#
# Dumper for the MetagenomicsDB database
#==================================================================================================#
# DESCRIPTION
#
#	Dump all relations and views from the MetagenomicsDB database to compare the data
#	in different implementations.
#
#
# USAGE
#
# 	./dumpDb.sh SERVICE_NAME OUTDIR
#
#	Saves dumps and md5 checksum files to OUTDIR. Dumps exclude columns that could change
#	between different implementations like ids, foreign keys (instead they include the
#	columns that uniquely identify the respective records), and the id_change.
#	Any previous results in OUTDIR are overwritten without further warning.
#	Connection parameters for the database need to be provided in a .pg_service.conf
#	file (https://www.postgresql.org/docs/current/libpq-pgservice.html). The name of the
#	service in the config file needs to be provided as SERVICE_NAME.
#	The outputs are:
#	*) p_s_t_m:			Full data from patient, sample, type, and measurement relations.
#	*) p_s_seq:			Columns to uniquely identify patients and samples; full data from
#						sequence relations.
#	*) p_s_seq_c_tc_t:	Columns to uniquely identify patients, samples, and sequences;
#						full data for classification and taxonomy relations (indirectly: taxclass).
#	*) std:				Full data from standard relation.
#	*) vl:				Full data from v_lineages view.
#	*) vs:				Full data from v_samples view.
#	*) vt:				Full data from v_taxa view.
#	*) vm:				Full data from v_measurements view.
#	*) vmeta:			Full data from v_metadata view.
#
# CAVEATS
#
#	This script will dump all data, including personal patient data (if available). Thus, use for
#	internal testing only!
#
#==================================================================================================#


#------------------------------------------------------------#
# Internal functions
#------------------------------------------------------------#
dumpData () {
	echo -e ${1} > ${2}
	psql service=${3} -c "COPY (${4}) TO STDOUT WITH NULL '';" > tmp \
		|| { printf "ERROR: Could not create dump\n"; exit 1; }
	sed 's/\\\\/\\/g' "tmp" >> ${2}
	
	# Use Linux compatibility layer on BSD
	MD5SUM="md5sum"
	OS=$(uname -s)
	
	if [ "${OS}" == "FreeBSD" ]; then
		MD5SUM="/compat/linux/bin/md5sum"
	fi
	${MD5SUM} ${2} > ${2}.md5 || exit 1
}


#------------------------------------------------------------#
# CLI
#------------------------------------------------------------#
SERVICE=$1
OUTDIR=$2

if [ -z "${SERVICE}" ]; then
        echo "ERROR: No service provided."
        exit 1
else
	psql service=${SERVICE} -c '' || {
		printf "ERROR: Cannot connect to service ->${SERVICE}<-\n"; exit 1;}
fi

if [ -z "${OUTDIR}" ]; then
	echo "ERROR: No output directory provided."
	exit 1
else
	OUTDIR=$(realpath ${OUTDIR})
	if [ ! -d ${OUTDIR} ]; then
		echo "ERROR: Output directory ->${OUTDIR}<- does not exist."
		exit 1
	fi
fi

echo "INFO: Accessing service ->${SERVICE}<-"
echo "INFO: Saving results to ->${OUTDIR}<-"
cd ${OUTDIR} || exit 1


#------------------------------------------------------------#
# Dump relations
#------------------------------------------------------------#
# patient, sample, type, measurement
echo "INFO: Dumping patient, sample, type, measurement"
DUMPF="p_s_t_m"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\t\
	smplCreator\tsmplCtrl\tmeasureName\tmeasureType\tmeasureSelect\t\
	measureValue"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, \
	s.createdby, s.iscontrol, t.name, t.type, t.selection, m.value \
	from patient p left outer join sample s on p.id = s.id_patient \
	left outer join measurement m on s.id = m.id_sample right outer join \
	type t on t.id = m.id_type order by p.alias, p.accession, \
	p.birthdate, s.createdate, s.iscontrol, t.name"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# patient, sample, sequence
echo "INFO: Dumping patient, sample, sequence"
DUMPF="p_s_seq"
HEADER="patAlias\tpatAccession\tpatBirthDate\tsmplDate\t\
	smplCtrl\tseqFlowcell\tseqRun\tseqBar\tseqRead\tseqCaller\t\
	seqNucs\tseqQual\tseqErr\tseqLen"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, \
	s.iscontrol, seq.flowcellid, seq.runid, seq.barcode, \
	seq.readid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, \
	seq.seqlen from patient p left outer join sample s on p.id = s.id_patient \
	left outer join sequence seq on s.id = seq.id_sample order by \
	p.alias, p.accession, p.birthdate, s.createdate, s.iscontrol, \
	seq.runid, seq.barcode, seq.readid"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# patient, sample, sequence, classification, taxclass, taxonomy
echo "INFO: Dumping patient, sample, sequence, classification, taxclass, taxonomy"
DUMPF="p_s_seq_c_tc_t"
HEADER="patAlias\tpatAccession\tpatBirthDate\tsmplDate\t\
	smplCtrl\tseqRun\tseqBar\tseqRead\tclassProg\tclassDb\t\
	taxName\ttaxRank"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, \
	s.iscontrol, seq.runid, seq.barcode, seq.readid, c.program, \
	c.database, t.name, t.rank from patient p left outer join sample s \
	on p.id = s.id_patient left outer join sequence seq on s.id = seq.id_sample \
	left outer join classification c on c.id_sequence = seq.id left outer join \
	taxclass tc on tc.id_classification = c.id right outer join taxonomy t \
	on t.id = tc.id_taxonomy order by p.alias, p.accession, p.birthdate, \
	s.createdate, s.iscontrol, seq.runid, seq.barcode, seq.readid, c.program, \
	c.database, t.name, t.rank"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# standard
echo "INFO: Dumping standard"
DUMPF="std"
HEADER="#stdName\tstdSex\tstdAge\tstdL\tstdM\tstdS"
CMD="select name, sex, age, l, m, s from standard order by name, sex, age"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"


#------------------------------------------------------------#
# Dump views
#------------------------------------------------------------#
# v_lineages
echo "INFO: Dumping v_lineages"
DUMPF="vl"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\tsmplCtrl\t\
	smplName\tclassProg\tclassDb\tclass\tclassCount"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, s.iscontrol, \
	vl.samplename, vl.program, vl.database, vl.class, vl.count from v_lineages vl \
	inner join sample s on s.id = vl.id inner join patient p on s.id_patient = p.id \
	order by p.alias, p.accession, p.birthdate, s.createdate, s.iscontrol, \
	vl.program, vl.database, vl.class"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# v_samples
echo "INFO: Dumping v_samples"
DUMPF="vs"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\tsmplTimepoint\t\
	smplCtrl\tsmplSeqC\tsmplOK"
CMD="select p.alias, p.accession, p.birthdate, vs.createdate, vs.timepoint, \
	vs.iscontrol, vs.seqcount, vs.isok from v_samples vs inner join patient p \
	on p.id = vs.id_patient order by p.alias, p.accession, p.birthdate, \
	vs.createdate, vs.iscontrol"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# v_taxa
echo "INFO: Dumping v_taxa"
DUMPF="vt"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\tsmplTimepoint\t\
	smplCtrl\tclassProg\tclassDb\tclassCount\ttaxName\ttaxRank\tseqMinLen\t\
	seqAvgLen\tseqMaxLen\tseqMinQual\tseqAvgQual\tseqMaxQual"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, vt.timepoint, \
	vt.iscontrol, vt.program, vt.database, vt.count, vt.name, vt.rank, vt.minlen, \
	vt.avglen, vt.maxlen, vt.minqual, vt.avgqual, vt.maxqual from patient p \
	inner join v_taxa vt on p.id = vt.id_patient inner join sample s on \
	s.id = vt.id_sample order by p.alias, p.accession, p.birthdate, s.createdate, \
	vt.iscontrol, vt.program, vt.database, vt.name, vt.rank"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# v_measurements
echo "INFO: Dumping v_measurements"
DUMPF="vm"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\tsmplTimepoint\t\
	measureName\tmeasureType\tmeasureValue"
CMD="select p.alias, p.accession, p.birthdate, vm.createdate, vm.timepoint, \
	vm.name, vm.type, vm.value from patient p inner join v_measurements vm \
	on p.id = vm.id_patient order by p.alias, p.accession, p.birthdate,	\
	vm.createdate, vm.name"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

# v_metadata
echo "INFO: Dumping v_metadata"
DUMPF="vmeta"
HEADER="#patAlias\tpatAccession\tpatBirthDate\tsmplDate\tsmplName\t\
	measureName\tmeasureType\tmeasureValue"
CMD="select p.alias, p.accession, p.birthdate, s.createdate, vmeta.samplename, \
	vmeta.name, vmeta.type, vmeta.value from v_metadata vmeta inner join sample s \
	on s.id = vmeta.id_sample inner join patient p on p.id = s.id_patient order by \
	p.alias, p.accession, p.birthdate, s.createdate, vmeta.name"
dumpData "${HEADER}" "${DUMPF}" "${SERVICE}" "${CMD}"

rm "tmp" || { printf "ERROR: Could not remove tmp file\n"; exit 1; }
echo "DONE"