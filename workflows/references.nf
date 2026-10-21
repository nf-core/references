include { PREPARE_GENOME } from '../subworkflows/local/prepare_genome'

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
    ch_prepare_genome = PREPARE_GENOME(
        fasta,
        fasta_fai,
        gff,
        gtf,
        splice_sites,
        transcript_fasta,
        vcf,
        altliftoverfile,
        tools,
        hisat2_build_memory,
        hisat2_skip_splice_sites,
    )

    emit:
    bowtie1_index     = ch_prepare_genome.bowtie1_index
    bowtie2_index     = ch_prepare_genome.bowtie2_index
    bwamem1_index     = ch_prepare_genome.bwamem1_index
    bwamem2_index     = ch_prepare_genome.bwamem2_index
    dragmap_hashmap   = ch_prepare_genome.dragmap_hashmap
    fasta
    fasta_dict        = ch_prepare_genome.fasta_dict
    fasta_fai         = ch_prepare_genome.fasta_fai
    fasta_sizes       = ch_prepare_genome.fasta_sizes
    gff
    gtf               = ch_prepare_genome.gtf
    hisat2_index      = ch_prepare_genome.hisat2_index
    intervals_bed     = ch_prepare_genome.intervals_bed
    kallisto_index    = ch_prepare_genome.kallisto_index
    msisensorpro_list = ch_prepare_genome.msisensorpro_list
    rsem_index        = ch_prepare_genome.rsem_index
    salmon_index      = ch_prepare_genome.salmon_index
    snapaligner_index = ch_prepare_genome.snapaligner_index
    splice_sites      = ch_prepare_genome.splice_sites
    star_index        = ch_prepare_genome.star_index
    transcript_fasta  = ch_prepare_genome.transcript_fasta
    vcf_tbi           = ch_prepare_genome.vcf_tbi
}
