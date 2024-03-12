include { BWA_INDEX as BWAMEM1_INDEX } from '../../modules/nf-core/bwa/index/main'
include { BWAMEM2_INDEX } from '../../modules/nf-core/bwamem2/index/main'

workflow SAREK {
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

    BWAMEM1_INDEX(input.fasta)
    BWAMEM2_INDEX(input.fasta)

    emit:
    bwa = BWAMEM1_INDEX.out.index.map{ meta, index -> [index] }.collect()
    bwamem2 = BWAMEM2_INDEX.out.index.map{ meta, index -> [index] }.collect()
}
