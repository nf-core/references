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
    run_bwamem1 // boolean: true/false
    run_bwamem2 // boolean: true/false
    run_createsequencedictionary // boolean: true/false
    run_dragmap // boolean: true/false
    run_faidx // boolean: true/false
    run_intervals // boolean: true/false
    run_msisensorpro // boolean: true/false
    run_tabix // boolean: true/false
    run_snapaligner // boolean: true/false

    main:
    bwamem1_index = channel.empty()
    bwamem2_index = channel.empty()
    dragmap_hashmap = channel.empty()
    fasta_dict = channel.empty()
    intervals_bed = channel.empty()
    msisensorpro_list = channel.empty()
    vcf_gz = channel.empty()
    vcf_tbi = channel.empty()
    snapaligner_index = channel.empty()

    if (run_bwamem1) {
        BWAMEM1_INDEX(fasta)

        bwamem1_index = BWAMEM1_INDEX.out.index
    }

    if (run_bwamem2) {
        BWAMEM2_INDEX(fasta)

        bwamem2_index = BWAMEM2_INDEX.out.index
    }

    if (run_dragmap) {
        DRAGMAP_HASHTABLE(fasta)

        dragmap_hashmap = DRAGMAP_HASHTABLE.out.hashmap
    }

    if (run_createsequencedictionary) {
        GATK4_CREATESEQUENCEDICTIONARY(fasta)

        fasta_dict = GATK4_CREATESEQUENCEDICTIONARY.out.dict
    }

    if (run_faidx || run_intervals) {

        if (run_faidx) {
            // Do not generate sizes for DNAseq
            generate_sizes = false

            SAMTOOLS_FAIDX(fasta.map { meta, fasta_ -> [meta, fasta_, []] }, generate_sizes)

            fasta_fai = fasta_fai.mix(SAMTOOLS_FAIDX.out.fai)
        }

        if (run_intervals) {
            BUILD_INTERVALS(fasta_fai, [], false)
            intervals_bed = BUILD_INTERVALS.out.output
        }
    }

    if (run_msisensorpro) {
        MSISENSORPRO_SCAN(fasta)

        msisensorpro_list = MSISENSORPRO_SCAN.out.list
    }

    if (run_tabix) {
        HTSLIB_BGZIPTABIX(
            vcf.map { meta, vcf_ -> [meta, vcf_, [], []] },
            "compress",
            true,
            "vcf",
        )

        vcf_gz = HTSLIB_BGZIPTABIX.out.output.map { meta, out -> [meta, out] }
        vcf_tbi = HTSLIB_BGZIPTABIX.out.index.map { meta, idx -> [meta, idx] }
    }

    if (run_snapaligner) {
        def snap_input = fasta
            .combine(altliftoverfile)
            .map { meta, fasta_, altliftoverfile_ ->
                [meta, fasta_, [], [], altliftoverfile_]
            }
        SNAPALIGNER_INDEX(snap_input)

        snapaligner_index = snapaligner_index.mix(SNAPALIGNER_INDEX.out.index)
    }

    emit:
    bwamem1_index // channel: [meta, BWAmemIndex/]
    bwamem2_index // channel: [meta, BWAmem2memIndex/]
    dragmap_hashmap // channel: [meta, DragmapHashtable/]
    fasta_dict // channel: [meta, *.fa(sta).dict]
    fasta_fai // channel: [meta, *.fa(sta).fai]
    intervals_bed // channel: [meta, *.bed]
    msisensorpro_list // channel: [meta, *.list]
    snapaligner_index // channel: [meta, snap/]
    vcf_gz // channel: [meta, *.vcf.gz]
    vcf_tbi // channel: [meta, *.vcf.gz.tbi]
}
