include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD } from "./modules/nf-core/bowtie2/build/main"

workflow INDEX {
    take:
    fasta

    main:
    meta_fasta = fasta.map{ fasta -> [ [ id:fasta.baseName ], file(fasta) ] }

    BOWTIE_BUILD ( file(fasta) )
    BOWTIE2_BUILD ( meta_fasta )

    emit:
    bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
}
