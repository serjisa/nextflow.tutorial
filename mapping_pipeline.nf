params.out = "results/"
params.n_cores = 8
params.SRA = "SRR11816045,SRR11815973"
params.genome_link = "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz"

SRA = params.SRA.split(",")

log.info ""
log.info "   W G S    A L I G N M E N T   "
log.info "================================"
log.info "Link for the genome  : ${params.genome_link}"
log.info "SRA IDs              : ${SRA}"
log.info "Output directory     : ${params.out}"
log.info "Number of threads    : ${params.n_cores}"
log.info ""

process DownloadGenome {
  input:
    val link

  output:
    path "genome.fasta"

  script:
    """
    if [[ "$link" == *.gz ]]
    then
        curl ${link} -o genome.fasta.gz
        gunzip genome.fasta.gz
    else
        curl ${link} -o genome.fasta
    fi
    """
}

process BuildIndex {
  input:
    path genome

  output:
    path "index"

  script:
    """
    mkdir index
    bowtie2-build ${genome} index/index
    """
}

process DownloadReads {
  input:
    val sra

  output:
    path "${sra}"

  script:
    """
    mkdir ${sra}
    cd ${sra} && wget \$(ffq --ftp ${sra} | jq -r '.[] | .url' | tr '\n' ' ')
    """
}

process FastQC {
  input:
    path reads

  output:
    path "${reads}/fastqc/*"

  script:
    """
    mkdir ${reads}/fastqc
    fastqc --noextract -o ${reads}/fastqc ${reads}/*.fastq.gz
    """
}

process Mapping {
  publishDir "${params.out}"

  input:
    path index
    path reads
    val n_cores

  output:
    path "${reads}"

  script:
    """
    id=\$(basename -- "${reads}")
    bowtie2 --no-unal -p ${n_cores} -x ${index}/index \
        -1 ${reads}/*_1.fastq.gz -2 ${reads}/*_2.fastq.gz \
        -S ${reads}/\$id.sam 2> ${reads}/\$id.log
    samtools view -bS \
        ${reads}/\$id.sam > ${reads}/\$id.bam
    rm ${reads}/\$id.sam
    """
}

process MultiQC {
  publishDir "${params.out}"

  input:
    path alignments
    path fastqc

  output:
    path "multiqc_report.html"

  script:
    """
    multiqc .
    """
}

workflow {
  DownloadGenome( params.genome_link )
  BuildIndex( DownloadGenome.out )
  data = Channel.of( SRA )
  DownloadReads( data )
  FastQC( DownloadReads.out )
  Mapping( BuildIndex.out, DownloadReads.out, params.n_cores )
  MultiQC( Mapping.out.collect(), FastQC.out.collect() )
}
