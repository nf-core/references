include { BWAMEM2_INDEX                  } from '../../../modules/nf-core/bwamem2/index'
include { BWA_INDEX as BWAMEM1_INDEX     } from '../../../modules/nf-core/bwa/index'
include { DRAGMAP_HASHTABLE              } from '../../../modules/nf-core/dragmap/hashtable'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../../../modules/nf-core/gatk4/createsequencedictionary'
include { GAWK as BUILD_INTERVALS        } from '../../../modules/nf-core/gawk'
include { MSISENSORPRO_SCAN              } from '../../../modules/nf-core/msisensorpro/scan'
include { SAMTOOLS_FAIDX                 } from '../../../modules/nf-core/samtools/faidx'
include { HTSLIB_BGZIPTABIX              } from '../../../modules/nf-core/htslib/bgziptabix'
include { SNAPALIGNER_INDEX              } from '../../../modules/nf-core/snapaligner/index'

workflow PREPARE_GENOME_DNASEQ {
    take:
    fasta // channel: [meta, fasta]
    fasta_fai // channel: [meta, fasta_fai]
    vcf // channel: [meta, vcf]
    altliftoverfile // channel: altliftoverfile
    tools // List: tools to build references for

    main:

    run_faidx = ('faidx' in tools) && !('intervals' in tools || 'sizes' in tools)

    BWAMEM1_INDEX(fasta.filter { meta, _fasta -> 'bwamem1' in tools && meta.run_bwamem1 })

    BWAMEM2_INDEX(fasta.filter { meta, _fasta -> 'bwamem2' in tools && meta.run_bwamem2 })

    DRAGMAP_HASHTABLE(fasta.filter { meta, _fasta -> 'dragmap' in tools && meta.run_dragmap })

    GATK4_CREATESEQUENCEDICTIONARY(fasta.filter { meta, _fasta -> 'createsequencedictionary' in tools && meta.run_createsequencedictionary })

    // Do not generate sizes for DNAseq
    generate_sizes = false

    SAMTOOLS_FAIDX(fasta.filter { meta, _fasta -> run_faidx && meta.run_faidx }.map { meta, fasta_ -> [meta, fasta_, []] }, generate_sizes)

    fasta_fai = fasta_fai.mix(SAMTOOLS_FAIDX.out.fai)

    BUILD_INTERVALS(fasta_fai.filter { meta, _fasta_fai -> 'intervals' in tools && meta.run_intervals }, [], false)

    MSISENSORPRO_SCAN(fasta.filter { meta, _fasta -> 'msisensorpro' in tools && meta.run_msisensorpro })

    HTSLIB_BGZIPTABIX(
        vcf.filter { meta, _vcf -> 'tabix' in tools && meta.run_tabix }.map { meta, vcf_ -> [meta, vcf_, null, null] },
        "compress",
        true,
        "vcf",
    )

    def fasta_for_snapaligner = altliftoverfile
        ? fasta.combine(altliftoverfile).map { meta, fasta_, altliftoverfile_ -> [meta, fasta_, [], [], altliftoverfile_] }
        : fasta.map { meta, fasta_ -> [meta, fasta_, [], [], []] }

    SNAPALIGNER_INDEX(fasta_for_snapaligner.filter { meta, _fasta, _altcontigfile, _nonaltcontigfile, _altliftoverfile -> 'snapaligner' in tools && meta.run_snapaligner })

    emit:
    bwamem1_index     = BWAMEM1_INDEX.out.index // channel: [meta, BWAmemIndex/]
    bwamem2_index     = BWAMEM2_INDEX.out.index // channel: [meta, BWAmem2memIndex/]
    dragmap_hashmap   = DRAGMAP_HASHTABLE.out.hashmap // channel: [meta, DragmapHashtable/]
    fasta_dict        = GATK4_CREATESEQUENCEDICTIONARY.out.dict // channel: [meta, *.fa(sta).dict]
    fasta_fai // channel: [meta, *.fa(sta).fai]
    intervals_bed     = BUILD_INTERVALS.out.output // channel: [meta, *.bed]
    msisensorpro_list = MSISENSORPRO_SCAN.out.list // channel: [meta, *.list]
    snapaligner_index = SNAPALIGNER_INDEX.out.index // channel: [meta, snap/]
    vcf_gz            = HTSLIB_BGZIPTABIX.out.output.map { meta, out -> [meta, out] } // channel: [meta, *.vcf.gz]
    vcf_tbi           = HTSLIB_BGZIPTABIX.out.index.map { meta, idx -> [meta, idx] } // channel: [meta, *.vcf.gz.tbi]
}
