include { validateParameters; paramsHelp; paramsSummaryLog; samplesheetToList } from 'plugin/nf-schema'
// Print help message, supply typical command line usage for the pipeline
if (params.help) {
   log.info paramsHelp("nextflow run my_pipeline --input input_file.csv")
   exit 0
}

// Validate input parameters
// TODO validateParameters()

// Print summary of supplied parameters
log.info paramsSummaryLog(workflow)

// Create a new channel of metadata from sample sheets passed to the pipeline through the --input parameter
ch_input = Channel.fromPath( params.input ).flatMap { samplesheetToList(it, "assets/schema_input.json") }

include { BOWTIE_BUILD } from "./modules/nf-core/bowtie/build/main"
include { BOWTIE2_BUILD } from "./modules/nf-core/bowtie2/build/main"

include { RNASEQ } from "./workflows/rnaseq/main"
include { SAREK } from "./workflows/sarek/main"

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

    BOWTIE_BUILD ( input.fasta )
    BOWTIE2_BUILD ( input.fasta )

    emit:
    // bowtie_index = BOWTIE_BUILD.out.index
    bowtie2_index = BOWTIE2_BUILD.out.index
}


workflow {
    INDEX ( ch_input )
    RNASEQ ( ch_input )
    SAREK ( ch_input )
}
