include { PREPARE_GENOME_DNASEQ } from '../subworkflows/local/prepare_genome_dnaseq'
include { PREPARE_GENOME_RNASEQ } from '../subworkflows/local/prepare_genome_rnaseq'

workflow REFERENCES {
    take:
    altliftoverfile
    fasta
    fasta_fai
    gff
    gtf
    splice_sites
    transcript_fasta
    vcf
    tools // List: Can contain any combination of tools
    hisat2_build_memory

    main:
    // Create references for rnaseq based pipelines such as nf-core/riboseq, nf-core/rnaseq, nf-core/rnavar
    PREPARE_GENOME_RNASEQ(
        fasta,
        fasta_fai,
        gff,
        gtf,
        splice_sites,
        transcript_fasta,
        tools,
        hisat2_build_memory,
    )

    // Create references for dnaseq based pipelines such as nf-core/sarek
    PREPARE_GENOME_DNASEQ(
        fasta,
        fasta_fai.mix(PREPARE_GENOME_RNASEQ.out.fasta_fai).unique(),
        vcf,
        altliftoverfile,
        tools,
    )

    emit:
    bowtie1_index     = PREPARE_GENOME_RNASEQ.out.bowtie1_index
    bowtie2_index     = PREPARE_GENOME_RNASEQ.out.bowtie2_index
    bwamem1_index     = PREPARE_GENOME_DNASEQ.out.bwamem1_index
    bwamem2_index     = PREPARE_GENOME_DNASEQ.out.bwamem2_index
    dragmap_hashmap   = PREPARE_GENOME_DNASEQ.out.dragmap_hashmap
    fasta
    fasta_dict        = PREPARE_GENOME_DNASEQ.out.fasta_dict
    fasta_fai         = PREPARE_GENOME_DNASEQ.out.fasta_fai
    fasta_sizes       = PREPARE_GENOME_RNASEQ.out.fasta_sizes
    gff
    gtf               = PREPARE_GENOME_RNASEQ.out.gtf
    hisat2_index      = PREPARE_GENOME_RNASEQ.out.hisat2_index
    intervals_bed     = PREPARE_GENOME_DNASEQ.out.intervals_bed
    kallisto_index    = PREPARE_GENOME_RNASEQ.out.kallisto_index
    msisensorpro_list = PREPARE_GENOME_DNASEQ.out.msisensorpro_list
    rsem_index        = PREPARE_GENOME_RNASEQ.out.rsem_index
    salmon_index      = PREPARE_GENOME_RNASEQ.out.salmon_index
    snapaligner_index = PREPARE_GENOME_DNASEQ.out.snapaligner_index
    splice_sites      = PREPARE_GENOME_RNASEQ.out.splice_sites
    star_index        = PREPARE_GENOME_RNASEQ.out.star_index
    transcript_fasta  = PREPARE_GENOME_RNASEQ.out.transcript_fasta
    vcf_tbi           = PREPARE_GENOME_DNASEQ.out.vcf_tbi
}
