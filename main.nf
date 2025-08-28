#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/references
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/references
    Website: https://nf-co.re/references
    Slack  : https://nfcore.slack.com/channels/references
----------------------------------------------------------------------------------------
*/

nextflow.preview.output = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap        } from 'plugin/nf-schema'
include { methodsDescriptionText  } from './subworkflows/local/utils_nfcore_references_pipeline'
include { paramsSummaryMultiqc    } from './subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML  } from './subworkflows/nf-core/utils_nfcore_pipeline'

include { MULTIQC                 } from './modules/nf-core/multiqc'

include { ARCHIVE_EXTRACT         } from './subworkflows/nf-core/archive_extract'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_references_pipeline'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_references_pipeline'
include { DATASHEET_TO_CHANNEL    } from './subworkflows/local/datasheet_to_channel'

include { REFERENCES              } from "./workflows/references"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    main:
    // SUBWORKFLOW: Run initialisation tasks
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        args,
        params.outdir,
        params.input,
        params.references_base_path,
        ['s3://ngi-igenomes/igenomes/'],
    )

    // WORKFLOW: Run main workflow
    if (!params.tools) {
        log.warn("No tools specified")
    }

    NFCORE_REFERENCES(PIPELINE_INITIALISATION.out.references, params.tools ?: "no_tools")

    ch_multiqc_files = Channel.empty()

    // MODULE: MultiQC
    ch_multiqc_config = Channel.fromPath("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(softwareVersionsToYAML(NFCORE_REFERENCES.out.versions).collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_references_software_mqc_versions.yml', sort: true, newLine: true))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    // SUBWORKFLOW: Run completion tasks
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        MULTIQC.out.report.toList(),
    )

    publish:
    multiqc = MULTIQC.out.data.mix(MULTIQC.out.plots, MULTIQC.out.report)
    references = NFCORE_REFERENCES.out.references
        .filter { _meta, file -> !(file instanceof String) }
        .map { meta, file ->
            // Filter out the run_ keys from the meta for a clearer index file
            def invalid_keys = meta.keySet().findAll { key -> key.startsWith('run_') }

            def path = ""
            def version = null

            if (meta.file == "bowtie1_index") {
                path = "Sequence/Index"
                version = "1.3.1"
            }
            else if (meta.file == "bowtie2_index") {
                path = "Sequence/Index"
                version = "2.5.2"
            }
            else if (meta.file == "bwamem1_index") {
                path = "Sequence/Index"
                version = "0.7.18"
            }
            else if (meta.file == "bwamem2_index") {
                path = "Sequence/Index"
                version = "2.2.1"
            }
            else if (meta.file == "dragmap_hashmap") {
                path = "Sequence/Index"
                version = "1.2.1"
            }
            else if (meta.file == "fasta" || meta.file == "fasta_dict" || meta.file == "fasta_fai" || meta.file == "fasta_sizes") {
                path = "Sequence/WholeGenomeFasta"
            }
            else if (meta.file == "gff" || meta.file == "gtf") {
                path = "Annotation/Genes"
            }
            else if (meta.file == "hisat2_index") {
                version = "2.2.1"
                path = meta.source_version == "unknown"
                    ? "Sequence/Index"
                    : "Sequence/Index/${meta.source_version}"
            }
            else if (meta.file == "intervals_bed") {
                path = "Annotation/intervals"
            }
            else if (meta.file == "kallisto_index") {
                version = "0.51.1"
                path = meta.source_version == "unknown"
                    ? "Sequence/Index"
                    : "Sequence/Index/${meta.source_version}"
            }
            else if (meta.file == "msisensorpro_list") {
                path = "Annotation/msisensorpro"
            }
            else if (meta.file == "rsem_index") {
                version = "1.3.1"
                path = meta.source_version == "unknown"
                    ? "Sequence/Index"
                    : "Sequence/Index/${meta.source_version}"
            }
            else if (meta.file == "salmon_index") {
                version = "1.10.3"
                path = meta.source_version == "unknown"
                    ? "Sequence/Index"
                    : "Sequence/Index/${meta.source_version}"
            }
            else if (meta.file == "splice_sites") {
                path = "Sequence/SpliceSites"
            }
            else if (meta.file == "star_index") {
                version = "2.7.11b"
                path = meta.source_version == "unknown"
                    ? "Sequence/Index"
                    : "Sequence/Index/${meta.source_version}"
            }
            else if (meta.file == "transcript_fasta") {
                path = "Sequence/TranscriptFasta"
            }
            else if (meta.file == "${meta.type}_vcf" || meta.file == "${meta.type}_vcf_tbi") {
                path = "Annotation/${meta.source_vcf}"
            }

            meta + [file: file, path: "${meta.species}/${meta.source}/${meta.genome}/${path}", version: version] - meta.subMap(invalid_keys)
        }
}

output {
    multiqc {
        path "multiqc"
    }
    references {
        path { reference ->
            if (reference.version) {
                "${reference.path}/${reference.file.baseName}_v${reference.version}"
            }
            else {
                "${reference.path}"
            }
        }

        index {
            path "index.json"
            sep ":"
        }
    }
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Helper function to check if a reference needs to be extracted
// Add the reference type to the meta
// Depending on the extension, return the appropriate channel
def need_extract(channel, type) {
    return channel
        .map { meta, reference_ -> [meta + [reference: type], reference_] }
        .branch { _meta, reference_ ->
            to_extract: reference_.toString().endsWith('.gz') || reference_.toString().endsWith('.zip')
            not_extracted: true
        }
}

// WORKFLOW: Build references depending on type of reference and the tools specified
workflow NFCORE_REFERENCES {
    take:
    references
    tools      // list of tools to use to build references

    main:

    DATASHEET_TO_CHANNEL(references, tools)

    // References that need to be extracted
    // (VCFs are not extracted)
    ascat_alleles_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_alleles, 'ascat_alleles')
    ascat_loci_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci, 'ascat_loci')
    ascat_loci_gc_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci_gc, 'ascat_loci_gc')
    ascat_loci_rt_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci_rt, 'ascat_loci_rt')
    chr_dir_input = need_extract(DATASHEET_TO_CHANNEL.out.chr_dir, 'chr_dir')
    fasta_input = need_extract(DATASHEET_TO_CHANNEL.out.fasta, 'fasta')
    gff_input = need_extract(DATASHEET_TO_CHANNEL.out.gff, 'gff')
    gtf_input = need_extract(DATASHEET_TO_CHANNEL.out.gtf, 'gtf')

    // gather all archived references
    archive_to_extract = Channel.empty()
        .mix(
            ascat_alleles_input.to_extract,
            ascat_loci_input.to_extract,
            ascat_loci_gc_input.to_extract,
            ascat_loci_rt_input.to_extract,
            chr_dir_input.to_extract,
            fasta_input.to_extract,
            gff_input.to_extract,
            gtf_input.to_extract,
        )

    // Extract references from any archive format
    ARCHIVE_EXTRACT(
        archive_to_extract
    )

    // return to the appropriate channels
    extracted_reference = ARCHIVE_EXTRACT.out.extracted.branch { meta_, _extracted_reference ->
        ascat_alleles: meta_.reference == 'ascat_alleles'
        ascat_loci: meta_.reference == 'ascat_loci'
        ascat_loci_gc: meta_.reference == 'ascat_loci_gc'
        ascat_loci_rt: meta_.reference == 'ascat_loci_rt'
        chr_dir: meta_.reference == 'chr_dir'
        fasta: meta_.reference == 'fasta'
        gff: meta_.reference == 'gff'
        gtf: meta_.reference == 'gtf'
        non_assigned: true
    }

    // This is a confidence check
    extracted_reference.non_assigned.view { reference -> log.warn("Non assigned extracted reference: " + reference) }

    // WORKFLOW: Run pipeline
    // Mix the references that were extracted with the references that did not need to be extracted
    // Some references are not extracted because they are usually not stored in an archived format
    // TODO: check if more references need to be extracted
    altliftoverfile = Channel.empty()

    REFERENCES(
        altliftoverfile,
        ascat_alleles_input.not_extracted.mix(extracted_reference.ascat_alleles),
        ascat_loci_input.not_extracted.mix(extracted_reference.ascat_loci),
        ascat_loci_gc_input.not_extracted.mix(extracted_reference.ascat_loci_gc),
        ascat_loci_rt_input.not_extracted.mix(extracted_reference.ascat_loci_rt),
        chr_dir_input.not_extracted.mix(extracted_reference.chr_dir),
        fasta_input.not_extracted.mix(extracted_reference.fasta),
        DATASHEET_TO_CHANNEL.out.fasta_dict,
        DATASHEET_TO_CHANNEL.out.fasta_fai,
        DATASHEET_TO_CHANNEL.out.fasta_sizes,
        gff_input.not_extracted.mix(extracted_reference.gff),
        gtf_input.not_extracted.mix(extracted_reference.gtf),
        DATASHEET_TO_CHANNEL.out.intervals_bed,
        DATASHEET_TO_CHANNEL.out.splice_sites,
        DATASHEET_TO_CHANNEL.out.transcript_fasta,
        DATASHEET_TO_CHANNEL.out.vcf,
        tools,
    )

    emit:
    references = REFERENCES.out.references
    versions   = REFERENCES.out.versions.mix(ARCHIVE_EXTRACT.out.versions)
}
