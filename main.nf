include { fromSamplesheet } from 'plugin/nf-validation'

include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD } from "./modules/nf-core/bowtie2/build/main"
include { STAR_GENOMEGENERATE } from "./modules/nf-core/star/genomegenerate/main"

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
    STAR_GENOMEGENERATE ( input.fasta, input.gtf )

    emit:
    // bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
    star_index = STAR_GENOMEGENERATE.out.index
}


workflow {
    ch_input = Channel.fromSamplesheet("input")

    INDEX ( ch_input )
}
