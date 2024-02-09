include { fromSamplesheet } from 'plugin/nf-validation'

include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD } from "./modules/nf-core/bowtie2/build/main"
// RNASEQ
include { STAR_GENOMEGENERATE } from "./modules/nf-core/star/genomegenerate/main"
// TODO
include { HISAT2_EXTRACTSPLICESITES } from "./modules/nf-core/hisat2/extractsplicesites"
include { HISAT2_BUILD } from "./modules/nf-core/hisat2/build"
// include { SALMON_INDEX } from "./modules/nf-core/salmon/index"
// include { KALLISTO_INDEX } from "./modules/nf-core/kallisto/index"
// include { RSEM_PREPAREREFERENCE as RSEM_PREPAREREFERENCE_GENOME } from "./modules/nf-core/rsem/preparereference"
// include { RSEM_PREPAREREFERENCE as MAKE_TRANSCRIPTS_FASTA } from "./modules/nf-core/rsem/preparereference"

workflow RNASEQ {
    take:
    reference // fasta, gtf

    main:
    reference
        .multiMap { meta, fasta, gtf, bed, readme, mito, size ->
            fasta: tuple(meta, fasta)
            gtf:   tuple(meta, gtf)
            bed:   tuple(meta, bed)
        }
        .set { input }

    STAR_GENOMEGENERATE ( input.fasta, input.gtf )

    ch_splicesites = HISAT2_EXTRACTSPLICESITES ( input.gtf ).txt.map { it[1] }
    HISAT2_BUILD ( input.fasta, input.gtf, ch_splicesites.map { [ [:], it ] } )

    emit:
    star_index = STAR_GENOMEGENERATE.out.index
    hisat2_index = HISAT2_BUILD.out.index
}

// TODO workflow SAREK {

workflow INDEX {
    take:
    reference // fasta, gtf

    main:
    reference
        .multiMap { meta, fasta, gtf, bed, readme, mito, size ->
            fasta: tuple(meta, fasta)
            gtf:   tuple(meta, gtf)
            bed:   tuple(meta, bed)
        }
        .set { input }

    BOWTIE_BUILD ( input.fasta )
    BOWTIE2_BUILD ( input.fasta )

    emit:
    // bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
}


workflow {
    ch_input = Channel.fromSamplesheet("input")

    INDEX ( ch_input )
    RNASEQ ( ch_input )
}
