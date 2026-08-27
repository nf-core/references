include { BOWTIE2_BUILD                                         } from '../../../modules/nf-core/bowtie2/build'
include { BOWTIE_BUILD as BOWTIE1_BUILD                         } from '../../../modules/nf-core/bowtie/build'
include { GFFREAD                                               } from '../../../modules/nf-core/gffread'
include { HISAT2_BUILD                                          } from '../../../modules/nf-core/hisat2/build'
include { HISAT2_EXTRACTSPLICESITES                             } from '../../../modules/nf-core/hisat2/extractsplicesites'
include { KALLISTO_INDEX                                        } from '../../../modules/nf-core/kallisto/index'
include { RSEM_PREPAREREFERENCE as MAKE_TRANSCRIPTS_FASTA       } from '../../../modules/nf-core/rsem/preparereference'
include { RSEM_PREPAREREFERENCE as RSEM_PREPAREREFERENCE_GENOME } from '../../../modules/nf-core/rsem/preparereference'
include { SALMON_INDEX                                          } from '../../../modules/nf-core/salmon/index'
include { SAMTOOLS_FAIDX                                        } from '../../../modules/nf-core/samtools/faidx'
include { STAR_GENOMEGENERATE                                   } from '../../../modules/nf-core/star/genomegenerate'

workflow PREPARE_GENOME_RNASEQ {
    take:
    fasta // channel: [meta, fasta]
    fasta_fai // channel: [meta, fasta_fai]
    gff // channel: [meta, gff]
    gtf // channel: [meta, gtf]
    splice_sites // channel: [meta, splice_sites]
    transcript_fasta // channel: [meta, transcript_fasta]
    tools // List: tools to build references for
    hisat2_build_memory

    main:

    run_faidx = 'faidx' in tools
    run_sizes = 'sizes' in tools

    BOWTIE1_BUILD(fasta.filter { meta, _fasta -> 'bowtie1' in tools && meta.run_bowtie1 })

    BOWTIE2_BUILD(fasta.filter { meta, _fasta -> 'bowtie2' in tools && meta.run_bowtie2 })

    SAMTOOLS_FAIDX(fasta.filter { meta, _fasta -> (run_faidx || run_sizes) && meta.run_faidx }.map { meta, fasta_ -> [meta, fasta_, []] }, run_sizes)

    fasta_fai = fasta_fai.mix(SAMTOOLS_FAIDX.out.fai)

    GFFREAD(join_by_meta_id(fasta, gff.filter { meta, _gff -> ('hisat2' in tools || 'kallisto' in tools || 'rsem' in tools || 'rsem_make_transcript_fasta' in tools || 'salmon' in tools || 'star' in tools) && meta.run_gffread }))

    gtf = gtf
        .mix(GFFREAD.out.gtf)
        .groupTuple()
        .map { meta, gtf_ -> gtf_[1] ? [meta, gtf_[1]] : [meta, gtf_[0]] }

    HISAT2_EXTRACTSPLICESITES(gtf.filter { meta, _gtf -> ('hisat2' in tools || 'hisat2_extractsplicesites' in tools) && meta.run_hisat2 })

    splice_sites = splice_sites.mix(HISAT2_EXTRACTSPLICESITES.out.txt)

    HISAT2_BUILD(join_by_meta_id(fasta.filter { meta, _fasta -> 'hisat2' in tools && meta.run_hisat2 }, gtf, splice_sites), hisat2_build_memory)

    MAKE_TRANSCRIPTS_FASTA(join_by_meta_id(fasta.filter { meta, _fasta -> 'rsem_make_transcript_fasta' in tools && meta.run_rsem_make_transcript_fasta }, gtf))

    transcript_fasta = transcript_fasta.mix(MAKE_TRANSCRIPTS_FASTA.out.transcript_fasta)

    KALLISTO_INDEX(transcript_fasta.filter { meta, _transcript_fasta -> 'kallisto' in tools && meta.run_kallisto })

    SALMON_INDEX(join_by_meta_id(fasta, transcript_fasta.filter { meta, _transcript_fasta -> 'salmon' in tools && meta.run_salmon }))

    RSEM_PREPAREREFERENCE_GENOME(join_by_meta_id(fasta.filter { meta, _fasta -> 'rsem' in tools && meta.run_rsem }, gtf))

    STAR_GENOMEGENERATE(join_by_meta_id(fasta.filter { meta, _fasta -> 'star' in tools && meta.run_star }, gtf))

    emit:
    bowtie1_index    = BOWTIE1_BUILD.out.index // channel: [meta, BowtieIndex/]
    bowtie2_index    = BOWTIE2_BUILD.out.index // channel: [meta, Bowtie2Index/]
    fasta_fai // channel: [meta, *.fa(sta).fai]
    fasta_sizes      = SAMTOOLS_FAIDX.out.sizes // channel: [meta, *.fa(sta).sizes]
    gtf // channel: [meta, gtf]
    hisat2_index     = HISAT2_BUILD.out.index // channel: [meta, Hisat2Index/]
    kallisto_index   = KALLISTO_INDEX.out.index // channel: [meta, KallistoIndex]
    rsem_index       = RSEM_PREPAREREFERENCE_GENOME.out.index // channel: [meta, RSEMIndex/]
    salmon_index     = SALMON_INDEX.out.index // channel: [meta, SalmonIndex/]
    splice_sites // channel: [meta, *.splice_sites.txt]
    star_index       = STAR_GENOMEGENERATE.out.index // channel: [meta, STARIndex/]
    transcript_fasta // channel: [meta, *.transcripts.fasta]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UTILITY FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def join_by_meta_id(channel1, channel2, channel3 = null) {
    if (channel3) {
        return channel1
            .map { meta, content1_ -> [meta.id, content1_, meta] }
            .join(channel2.map { meta, content2_ -> [meta.id, content2_, meta] })
            .join(channel3.map { meta, content3_ -> [meta.id, content3_, meta] })
            .map { _id, content1_, meta1, content2_, meta2, content3_, meta3 -> [meta3 + meta2 + meta1, content1_, content2_, content3_] }
    }
    else {
        return channel1
            .map { meta, content1_ -> [meta.id, content1_, meta] }
            .join(channel2.map { meta, content2_ -> [meta.id, content2_, meta] })
            .map { _id, content1_, meta1, content2_, meta2 -> [meta2 + meta1, content1_, content2_] }
    }
}
