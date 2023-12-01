include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"

workflow INDEX {
    take:
    fasta

    main:
    BOWTIE_BUILD ( file(fasta) )

    emit:
    bowtie_index = BOWTIE_BUILD.out.index
}
