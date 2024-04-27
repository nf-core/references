include { STAR_GENOMEGENERATE } from "../../modules/nf-core/star/genomegenerate/main"
include { HISAT2_EXTRACTSPLICESITES } from "../../modules/nf-core/hisat2/extractsplicesites"
include { HISAT2_BUILD } from "../../modules/nf-core/hisat2/build"
include { RSEM_PREPAREREFERENCE as MAKE_TRANSCRIPTS_FASTA } from "../../modules/nf-core/rsem/preparereference"
include { SALMON_INDEX } from "../../modules/nf-core/salmon/index"
include { KALLISTO_INDEX } from "../../modules/nf-core/kallisto/index"
include { RSEM_PREPAREREFERENCE as RSEM_PREPAREREFERENCE_GENOME } from "../../modules/nf-core/rsem/preparereference"

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

    // FIXME Need to unzip gtf
    ch_splicesites = HISAT2_EXTRACTSPLICESITES ( input.gtf ).txt.map { it[1] }
    HISAT2_BUILD ( input.fasta, input.gtf, ch_splicesites.map { [ [:], it ] } )

    ch_transcript_fasta = MAKE_TRANSCRIPTS_FASTA ( input.fasta, input.gtf ).transcript_fasta

    SALMON_INDEX ( input.fasta, ch_transcript_fasta )

    KALLISTO_INDEX ( ch_transcript_fasta.map{[ [:], it]} )

    RSEM_PREPAREREFERENCE_GENOME ( input.fasta, input.gtf )

    emit:
    star_index = STAR_GENOMEGENERATE.out.index
    hisat2_index = HISAT2_BUILD.out.index
    transcript_fasta = ch_transcript_fasta
    salmon_index = SALMON_INDEX.out.index
    kallisto_index = KALLISTO_INDEX.out.index
    rsem_index = RSEM_PREPAREREFERENCE_GENOME.out.index
}
