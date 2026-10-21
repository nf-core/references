include { BOWTIE2_BUILD                                         } from '../../../modules/nf-core/bowtie2/build'
include { BOWTIE_BUILD as BOWTIE1_BUILD                         } from '../../../modules/nf-core/bowtie/build'
include { BWAMEM2_INDEX                  } from '../../../modules/nf-core/bwamem2/index'
include { BWA_INDEX as BWAMEM1_INDEX     } from '../../../modules/nf-core/bwa/index'
include { DRAGMAP_HASHTABLE              } from '../../../modules/nf-core/dragmap/hashtable'
include { GFFREAD                                               } from '../../../modules/nf-core/gffread'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../../../modules/nf-core/gatk4/createsequencedictionary'
include { GAWK as BUILD_INTERVALS        } from '../../../modules/nf-core/gawk'
include { HISAT2_BUILD                                          } from '../../../modules/nf-core/hisat2/build'
include { HISAT2_EXTRACTSPLICESITES                             } from '../../../modules/nf-core/hisat2/extractsplicesites'
include { KALLISTO_INDEX                                        } from '../../../modules/nf-core/kallisto/index'
include { MSISENSORPRO_SCAN              } from '../../../modules/nf-core/msisensorpro/scan'
include { RSEM_PREPAREREFERENCE as MAKE_TRANSCRIPTS_FASTA       } from '../../../modules/nf-core/rsem/preparereference'
include { RSEM_PREPAREREFERENCE as RSEM_PREPAREREFERENCE_GENOME } from '../../../modules/nf-core/rsem/preparereference'
include { SALMON_INDEX                                          } from '../../../modules/nf-core/salmon/index'
include { SAMTOOLS_FAIDX                                        } from '../../../modules/nf-core/samtools/faidx'
include { HTSLIB_BGZIPTABIX              } from '../../../modules/nf-core/htslib/bgziptabix'
include { SNAPALIGNER_INDEX              } from '../../../modules/nf-core/snapaligner/index'
include { STAR_GENOMEGENERATE                                   } from '../../../modules/nf-core/star/genomegenerate'

workflow PREPARE_GENOME {
    take:
    fasta // channel: [meta, fasta]
    fasta_fai // channel: [meta, fasta_fai]
    gff // channel: [meta, gff]
    gtf // channel: [meta, gtf]
    splice_sites // channel: [meta, splice_sites]
    transcript_fasta // channel: [meta, transcript_fasta]
    vcf // channel: [meta, vcf]
    altliftoverfile // channel: altliftoverfile
    tools // List: tools to build references for
    hisat2_build_memory
    hisat2_skip_splice_sites

    main:

    run_faidx = 'faidx' in tools
    run_sizes = 'sizes' in tools

    // Aligner indexes
    ch_bowtie1_build = BOWTIE1_BUILD(fasta.filter { meta, _fasta -> 'bowtie1' in tools && meta.run_bowtie1 })

    ch_bowtie2_build = BOWTIE2_BUILD(fasta.filter { meta, _fasta -> 'bowtie2' in tools && meta.run_bowtie2 })

    ch_bwamem1_index = BWAMEM1_INDEX(fasta.filter { meta, _fasta -> 'bwamem1' in tools && meta.run_bwamem1 })

    ch_bwamem2_index = BWAMEM2_INDEX(fasta.filter { meta, _fasta -> 'bwamem2' in tools && meta.run_bwamem2 })

    ch_dragmap_hashtable = DRAGMAP_HASHTABLE(fasta.filter { meta, _fasta -> 'dragmap' in tools && meta.run_dragmap })

    // Annotation and transcript resources
    ch_gffread = GFFREAD(join_by_meta_id(fasta, gff.filter { meta, _gff -> ('hisat2' in tools || 'kallisto' in tools || 'rsem' in tools || 'rsem_make_transcript_fasta' in tools || 'salmon' in tools || 'star' in tools) && meta.run_gffread }))

    gtf = gtf
        .mix(ch_gffread.gtf)
        .groupBy()
        .map { meta, gtf_ -> gtf_[1] ? [meta, gtf_[1]] : [meta, gtf_[0]] }

    ch_hisat2_extractsplicesites = HISAT2_EXTRACTSPLICESITES(gtf.filter { meta, _gtf -> ('hisat2' in tools || 'hisat2_extractsplicesites' in tools) && meta.run_hisat2 && !hisat2_skip_splice_sites })

    splice_sites = splice_sites.mix(ch_hisat2_extractsplicesites.txt)

    ch_hisat2_build = HISAT2_BUILD(join_by_meta_id(fasta.filter { meta, _fasta -> 'hisat2' in tools && meta.run_hisat2 }, gtf, splice_sites), hisat2_build_memory)

    ch_make_transcripts_fasta = MAKE_TRANSCRIPTS_FASTA(join_by_meta_id(fasta.filter { meta, _fasta -> 'rsem_make_transcript_fasta' in tools && meta.run_rsem_make_transcript_fasta }, gtf))

    transcript_fasta = transcript_fasta.mix(ch_make_transcripts_fasta.transcript_fasta)

    ch_kallisto_index = KALLISTO_INDEX(transcript_fasta.filter { meta, _transcript_fasta -> 'kallisto' in tools && meta.run_kallisto })

    ch_salmon_index = SALMON_INDEX(join_by_meta_id(transcript_fasta, fasta.filter { meta, _fasta -> 'salmon' in tools && meta.run_salmon }))

    ch_rsem_preparereference_genome = RSEM_PREPAREREFERENCE_GENOME(join_by_meta_id(fasta.filter { meta, _fasta -> 'rsem' in tools && meta.run_rsem }, gtf))

    ch_star_genomegenerate = STAR_GENOMEGENERATE(join_by_meta_id(fasta.filter { meta, _fasta -> 'star' in tools && meta.run_star }, gtf))

    // Sequence dictionaries, indexes, and intervals
    ch_gatk4_dict = GATK4_CREATESEQUENCEDICTIONARY(fasta.filter { meta, _fasta -> 'createsequencedictionary' in tools && meta.run_createsequencedictionary })

    ch_samtools_faidx = SAMTOOLS_FAIDX(fasta.filter { meta, _fasta -> (run_faidx || run_sizes) && meta.run_faidx }.map { meta, fasta_ -> [meta, fasta_, []] }, run_sizes)

    fasta_fai = fasta_fai.mix(ch_samtools_faidx.fai)

    ch_build_intervals = BUILD_INTERVALS(fasta_fai.filter { meta, _fasta_fai -> 'intervals' in tools && meta.run_intervals }, [], false)

    ch_msisensorpro_scan = MSISENSORPRO_SCAN(fasta.filter { meta, _fasta -> 'msisensorpro' in tools && meta.run_msisensorpro })

    ch_bgziptabix = HTSLIB_BGZIPTABIX(
        vcf.filter { meta, _vcf -> 'tabix' in tools && meta.run_tabix }.map { meta, vcf_ -> [meta, vcf_, null, null] },
        "compress",
        true,
        "vcf",
    )

    def fasta_for_snapaligner = altliftoverfile
        ? fasta.combine(altliftoverfile).map { meta, fasta_, altliftoverfile_ -> [meta, fasta_, [], [], altliftoverfile_] }
        : fasta.map { meta, fasta_ -> [meta, fasta_, [], [], []] }

    ch_snapaligner_index = SNAPALIGNER_INDEX(fasta_for_snapaligner.filter { meta, _fasta, _altcontigfile, _nonaltcontigfile, _altliftoverfile -> 'snapaligner' in tools && meta.run_snapaligner })

    emit:
    bowtie1_index    = ch_bowtie1_build.index // channel: [meta, BowtieIndex/]
    bowtie2_index    = ch_bowtie2_build.index // channel: [meta, Bowtie2Index/]
    bwamem1_index     = ch_bwamem1_index.index // channel: [meta, BWAmemIndex/]
    bwamem2_index     = ch_bwamem2_index.index // channel: [meta, BWAmem2memIndex/]
    dragmap_hashmap   = ch_dragmap_hashtable.hashmap // channel: [meta, DragmapHashtable/]
    fasta_dict        = ch_gatk4_dict.dict // channel: [meta, *.fa(sta).dict]
    fasta_fai // channel: [meta, *.fa(sta).fai]
    fasta_sizes      = ch_samtools_faidx.sizes // channel: [meta, *.fa(sta).sizes]
    gtf // channel: [meta, gtf]
    hisat2_index     = ch_hisat2_build.index // channel: [meta, Hisat2Index/]
    intervals_bed     = ch_build_intervals.output // channel: [meta, *.bed]
    kallisto_index   = ch_kallisto_index.index // channel: [meta, KallistoIndex]
    msisensorpro_list = ch_msisensorpro_scan.list // channel: [meta, *.list]
    rsem_index       = ch_rsem_preparereference_genome.index // channel: [meta, RSEMIndex/]
    salmon_index     = ch_salmon_index.index // channel: [meta, SalmonIndex/]
    snapaligner_index = ch_snapaligner_index.index // channel: [meta, snap/]
    splice_sites // channel: [meta, *.splice_sites.txt]
    star_index       = ch_star_genomegenerate.index // channel: [meta, STARIndex/]
    transcript_fasta // channel: [meta, *.transcripts.fasta]
    vcf_gz            = ch_bgziptabix.output.map { meta, out -> [meta, out] } // channel: [meta, *.vcf.gz]
    vcf_tbi           = ch_bgziptabix.index.map { meta, idx -> [meta, idx] } // channel: [meta, *.vcf.gz.tbi]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UTILITY FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
