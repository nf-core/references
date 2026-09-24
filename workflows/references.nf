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
    hisat2_skip_splice_sites

    main:
    // Create references for rnaseq based pipelines such as nf-core/riboseq, nf-core/rnaseq, nf-core/rnavar
    ch_prepare_genome_rnaseq = PREPARE_GENOME_RNASEQ(
        fasta,
        fasta_fai,
        gff,
        gtf,
        splice_sites,
        transcript_fasta,
        tools,
        hisat2_build_memory,
        hisat2_skip_splice_sites,
    )

    // Create references for dnaseq based pipelines such as nf-core/sarek
    ch_prepare_genome_dnaseq = PREPARE_GENOME_DNASEQ(
        fasta,
        fasta_fai.mix(ch_prepare_genome_rnaseq.fasta_fai).unique(),
        vcf,
        altliftoverfile,
        tools,
    )

    emit:
    bowtie1_index     = ch_prepare_genome_rnaseq.bowtie1_index
    bowtie2_index     = ch_prepare_genome_rnaseq.bowtie2_index
    bwamem1_index     = ch_prepare_genome_dnaseq.bwamem1_index
    bwamem2_index     = ch_prepare_genome_dnaseq.bwamem2_index
    dragmap_hashmap   = ch_prepare_genome_dnaseq.dragmap_hashmap
    fasta
    fasta_dict        = ch_prepare_genome_dnaseq.fasta_dict
    fasta_fai         = ch_prepare_genome_dnaseq.fasta_fai
    fasta_sizes       = ch_prepare_genome_rnaseq.fasta_sizes
    gff
    gtf               = ch_prepare_genome_rnaseq.gtf
    hisat2_index      = ch_prepare_genome_rnaseq.hisat2_index
    intervals_bed     = ch_prepare_genome_dnaseq.intervals_bed
    kallisto_index    = ch_prepare_genome_rnaseq.kallisto_index
    msisensorpro_list = ch_prepare_genome_dnaseq.msisensorpro_list
    rsem_index        = ch_prepare_genome_rnaseq.rsem_index
    salmon_index      = ch_prepare_genome_rnaseq.salmon_index
    snapaligner_index = ch_prepare_genome_dnaseq.snapaligner_index
    splice_sites      = ch_prepare_genome_rnaseq.splice_sites
    star_index        = ch_prepare_genome_rnaseq.star_index
    transcript_fasta  = ch_prepare_genome_rnaseq.transcript_fasta
    vcf_tbi           = ch_prepare_genome_dnaseq.vcf_tbi
}
