include { BOWTIE_BUILD            } from "./../../modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD           } from "./../../modules/nf-core/bowtie2/build/main"


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

    // FIXME Can't access container
    // BOWTIE_BUILD ( input.fasta )
    BOWTIE2_BUILD ( input.fasta )

    emit:
    // bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
}
