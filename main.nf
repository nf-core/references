include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD } from "./modules/nf-core/bowtie2/build/main"
include { STAR_GENOMEGENERATE } from "./modules/nf-core/star/genomegenerate/main"

workflow INDEX {
    take:
    fasta
    gtf

    main:
    meta_fasta = fasta.map{ fasta -> [ [ id:fasta.baseName ], file(fasta) ] }
    meta_gtf = gtf.map{ gtf -> [ [ id:gtf.baseName ], file(gtf) ] }

    BOWTIE_BUILD ( file(fasta) )
    BOWTIE2_BUILD ( meta_fasta )
    STAR_GENOMEGENERATE ( meta_fasta, meta_gtf )

    emit:
    bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
    star_index = STAR_GENOMEGENERATE.out.index
}
