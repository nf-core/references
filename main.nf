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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ARCHIVE_EXTRACT          } from './subworkflows/nf-core/archive_extract'
include { NCBIDATASETSCLI_DATASETS } from './modules/local/ncbidatasetscli/datasets'
include { DATASHEET_TO_CHANNEL     } from './subworkflows/local/datasheet_to_channel'
include { defineToolsList          } from './subworkflows/local/utils_nfcore_references_pipeline'
include { PIPELINE_COMPLETION      } from './subworkflows/local/utils_nfcore_references_pipeline'
include { PIPELINE_INITIALISATION  } from './subworkflows/local/utils_nfcore_references_pipeline'
include { REFERENCES               } from "./workflows/references"

// MULTIQC & versions
include { MULTIQC                  } from './modules/nf-core/multiqc'
include { softwareVersionsToYAML   } from 'plugin/nf-core-utils'
include { methodsDescriptionText   } from './subworkflows/local/utils_nfcore_references_pipeline'
include { paramsSummaryMap         } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// WORKFLOW: Build references depending on type of reference and the tools specified
workflow NFCORE_REFERENCES {
    take:
    references
    tools // list of tools to use to build references

    main:

    DATASHEET_TO_CHANNEL(references, tools)

    // References that need to be extracted
    // (VCFs are not extracted)
    ascat_alleles_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_alleles, 'ascat_alleles')
    ascat_loci_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci, 'ascat_loci')
    ascat_loci_gc_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci_gc, 'ascat_loci_gc')
    ascat_loci_rt_input = need_extract(DATASHEET_TO_CHANNEL.out.ascat_loci_rt, 'ascat_loci_rt')
    chr_dir_input = need_extract(DATASHEET_TO_CHANNEL.out.chr_dir, 'chr_dir')

    fasta_download_input = need_ncbi_download(DATASHEET_TO_CHANNEL.out.fasta, 'fasta')
    gff_download_input = need_ncbi_download(DATASHEET_TO_CHANNEL.out.gff, 'gff')
    gtf_download_input = need_ncbi_download(DATASHEET_TO_CHANNEL.out.gtf, 'gtf')

    ncbi_download_input = fasta_download_input.to_download
        .mix(gff_download_input.to_download, gtf_download_input.to_download)
        .map { meta, _file ->
            [meta.source_version, meta.reference, meta]
        }
        .groupTuple()
        .map { acc, ref_types, metas ->
            def includes = ref_types
                .collect { reference_ ->
                    reference_ == 'fasta'
                        ? 'genome'
                        : reference_ == 'gff'
                            ? 'gff3'
                            : reference_ == 'gtf' ? 'gtf' : reference_
                }
                .unique()
                .sort()
                .join(',')
            def merged_meta = metas.inject([:]) { a, m -> a + m } + [accession: acc]
            [merged_meta, includes]
        }

    NCBIDATASETSCLI_DATASETS(ncbi_download_input)

    fasta_input = need_extract(fasta_download_input.not_downloaded, 'fasta')
    gff_input = need_extract(gff_download_input.not_downloaded, 'gff')
    gtf_input = need_extract(gtf_download_input.not_downloaded, 'gtf')

    // gather all archived references
    archive_to_extract = channel.empty()
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
    ARCHIVE_EXTRACT(archive_to_extract)

    // return to the appropriate channels
    extracted_fasta = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'fasta' }
    extracted_gff = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'gff' }
    extracted_gtf = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'gtf' }

    // This is a confidence check
    def assigned_references = ['ascat_alleles', 'ascat_loci', 'ascat_loci_gc', 'ascat_loci_rt', 'chr_dir', 'fasta', 'gff', 'gtf'] as Set
    ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> !(meta.reference in assigned_references) }.view { reference -> log.warn("Non assigned extracted reference: " + reference) }

    // WORKFLOW: Run pipeline
    // Mix the references that were extracted with the references that did not need to be extracted
    // Some references are not extracted because they are usually not stored in an archived format
    // TODO: check if more references need to be extracted
    altliftoverfile = false

    fasta = fasta_input.not_extracted.mix(extracted_fasta, NCBIDATASETSCLI_DATASETS.out.fna.map { meta, file -> [meta + record(reference: 'fasta', file: 'fasta'), file] })
    gff = gff_input.not_extracted.mix(extracted_gff, NCBIDATASETSCLI_DATASETS.out.gff.map { meta, file -> [meta + record(reference: 'gff', file: 'gff'), file] })
    gtf = gtf_input.not_extracted.mix(extracted_gtf, NCBIDATASETSCLI_DATASETS.out.gtf.map { meta, file -> [meta + record(reference: 'gtf', file: 'gtf'), file] })

    REFERENCES(
        altliftoverfile,
        fasta,
        DATASHEET_TO_CHANNEL.out.fasta_fai,
        gff,
        gtf,
        DATASHEET_TO_CHANNEL.out.splice_sites,
        DATASHEET_TO_CHANNEL.out.transcript_fasta,
        DATASHEET_TO_CHANNEL.out.vcf,
        tools,
        params.hisat2_build_memory,
    )

    emit:
    ascat_alleles     = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'ascat_alleles' }
    ascat_loci        = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'ascat_loci' }
    ascat_loci_gc     = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'ascat_loci_gc' }
    ascat_loci_rt     = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'ascat_loci_rt' }
    bowtie1_index     = REFERENCES.out.bowtie1_index
    bowtie2_index     = REFERENCES.out.bowtie2_index
    bwamem1_index     = REFERENCES.out.bwamem1_index
    bwamem2_index     = REFERENCES.out.bwamem2_index
    chr_dir           = ARCHIVE_EXTRACT.out.extracted.filter { meta, _ref -> meta.reference == 'chr_dir' }
    dragmap_hashmap   = REFERENCES.out.dragmap_hashmap
    fasta             = fasta
    fasta_dict        = REFERENCES.out.fasta_dict.mix(DATASHEET_TO_CHANNEL.out.fasta_dict)
    fasta_fai         = REFERENCES.out.fasta_fai
    fasta_sizes       = REFERENCES.out.fasta_sizes.mix(DATASHEET_TO_CHANNEL.out.fasta_sizes)
    gff               = gff
    gtf               = REFERENCES.out.gtf
    hisat2_index      = REFERENCES.out.hisat2_index
    intervals_bed     = REFERENCES.out.intervals_bed.mix(DATASHEET_TO_CHANNEL.out.intervals_bed)
    kallisto_index    = REFERENCES.out.kallisto_index
    msisensorpro_list = REFERENCES.out.msisensorpro_list
    rsem_index        = REFERENCES.out.rsem_index
    salmon_index      = REFERENCES.out.salmon_index
    snapaligner_index = REFERENCES.out.snapaligner_index
    splice_sites      = REFERENCES.out.splice_sites
    star_index        = REFERENCES.out.star_index
    transcript_fasta  = REFERENCES.out.transcript_fasta
    vcf               = DATASHEET_TO_CHANNEL.out.vcf
    vcf_tbi           = REFERENCES.out.vcf_tbi
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {

    // Path to yaml file containing information about the genome(s) and files to use for building references.
    input: String?

    // The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure.
    outdir: String?

    // Select a predefined bundle of tools to build references for.
    tools_bundle: String?

    // Specify which tools to build references for.
    tools: String?

    // Specify which tools to skip building references for.
    skip_tools: String?

    // The base path to the reference files
    references_base_path: String?

    // Email address for completion summary.
    email: String?

    // MultiQC report title. Printed as page header, used for filename if not otherwise specified.
    multiqc_title: String?

    // Make --make-unique flag for kallisto index
    kallisto_make_unique: Boolean = false

    // Memory threshold for HISAT2 index building. When available process memory meets or exceeds this value, splice sites and exons are used to build a splice-aware index.
    hisat2_build_memory: String = '200.GB'

    // Git commit id for Institutional configs.
    custom_config_version: String = 'master'

    // Base directory for Institutional configs.
    custom_config_base: String = 'https://raw.githubusercontent.com/nf-core/configs/master'

    // Institutional config name.
    config_profile_name: String?

    // Institutional config description.
    config_profile_description: String?

    // Institutional config contact information.
    config_profile_contact: String?

    // Institutional config URL link.
    config_profile_url: String?

    // Display version and exit.
    version: Boolean = false

    // Method used to save pipeline results to output directory.
    publish_dir_mode: String = 'copy'

    // Email address for completion summary, only when pipeline fails.
    email_on_fail: String?

    // Send plain-text email instead of HTML.
    plaintext_email: Boolean = false

    // File size limit when attaching MultiQC reports to summary emails.
    max_multiqc_email_size: String = '25.MB'

    // Do not use coloured log outputs.
    monochrome_logs: Boolean = false

    // Custom config file to supply to MultiQC.
    multiqc_config: Path?

    // Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file
    multiqc_logo: Path?

    // Custom MultiQC yaml file containing HTML including a methods description.
    multiqc_methods_description: Path?

    // Boolean whether to validate parameters against the schema at runtime
    validate_params: Boolean = true

    // Base URL or local path to location of pipeline test dataset files
    modules_testdata_base_path: String = 'https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/'

    // Base URL or local path to location of pipeline test dataset files
    pipelines_testdata_base_path: String = 'https://raw.githubusercontent.com/nf-core/test-datasets/'

    // Suffix to add to the trace report filename. Default is the date and time in the format yyyy-MM-dd_HH-mm-ss.
    trace_report_suffix: String

    // Display the help message.
    help: Boolean = false

    // Display the full detailed help message.
    help_full: Boolean = false

    // Display hidden parameters in the help message (only works when --help or --help_full are provided).
    show_hidden: Boolean = false
}

workflow {

    main:
    def tools = defineToolsList(params.tools_bundle, params.tools, params.skip_tools)

    // SUBWORKFLOW: Run initialisation tasks
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden,
        params.references_base_path,
        ['s3://ngi-igenomes/igenomes/'],
        tools,
    )

    // WORKFLOW: Run main workflow
    NFCORE_REFERENCES(PIPELINE_INITIALISATION.out.references, tools)

    // VERSIONS
    def collated_versions = softwareVersionsToYAML(
        softwareVersions: channel.topic("versions"),
        nextflowVersion: workflow.nextflow.version,
    ).collectFile(
        storeDir: "${params.outdir}/pipeline_info",
        name: 'nf_core_' + 'references_software_' + 'mqc_' + 'versions.yml',
        sort: true,
        newLine: true,
    )

    // MULTIQC
    def multiqc_files = channel.empty()
    def multiqc_report = channel.empty()

    multiqc_files = multiqc_files.mix(collated_versions)

    def summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    def multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def methods_description = channel.value(methodsDescriptionText(multiqc_custom_methods_description))

    multiqc_files = multiqc_files.mix(workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    multiqc_files = multiqc_files.mix(methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        multiqc_files.flatten().collect().map { files ->
            [
                [id: 'references'],
                files,
                params.multiqc_config
                    ? file(params.multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                params.multiqc_logo ? file(params.multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList()

    // SUBWORKFLOW: Run completion tasks
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        MULTIQC.out.report.toList(),
    )

    publish:
    multiqc           = MULTIQC.out.data.mix(MULTIQC.out.plots, MULTIQC.out.report)
    ascat_alleles     = NFCORE_REFERENCES.out.ascat_alleles
    ascat_loci        = NFCORE_REFERENCES.out.ascat_loci
    ascat_loci_gc     = NFCORE_REFERENCES.out.ascat_loci_gc
    ascat_loci_rt     = NFCORE_REFERENCES.out.ascat_loci_rt
    bowtie1_index     = NFCORE_REFERENCES.out.bowtie1_index
    bowtie2_index     = NFCORE_REFERENCES.out.bowtie2_index
    bwamem1_index     = NFCORE_REFERENCES.out.bwamem1_index
    bwamem2_index     = NFCORE_REFERENCES.out.bwamem2_index
    chr_dir           = NFCORE_REFERENCES.out.chr_dir
    dragmap_hashmap   = NFCORE_REFERENCES.out.dragmap_hashmap
    fasta             = NFCORE_REFERENCES.out.fasta
    fasta_dict        = NFCORE_REFERENCES.out.fasta_dict
    fasta_fai         = NFCORE_REFERENCES.out.fasta_fai
    fasta_sizes       = NFCORE_REFERENCES.out.fasta_sizes
    gff               = NFCORE_REFERENCES.out.gff
    gtf               = NFCORE_REFERENCES.out.gtf
    hisat2_index      = NFCORE_REFERENCES.out.hisat2_index
    intervals_bed     = NFCORE_REFERENCES.out.intervals_bed
    kallisto_index    = NFCORE_REFERENCES.out.kallisto_index
    msisensorpro_list = NFCORE_REFERENCES.out.msisensorpro_list
    rsem_index        = NFCORE_REFERENCES.out.rsem_index
    salmon_index      = NFCORE_REFERENCES.out.salmon_index
    snapaligner_index = NFCORE_REFERENCES.out.snapaligner_index
    splice_sites      = NFCORE_REFERENCES.out.splice_sites
    star_index        = NFCORE_REFERENCES.out.star_index
    transcript_fasta  = NFCORE_REFERENCES.out.transcript_fasta
    vcf_tbi           = NFCORE_REFERENCES.out.vcf_tbi
}

output {
    multiqc {
        path "multiqc"
    }
    ascat_alleles {
        path "ascat/"
    }
    ascat_loci {
        path "ascat/"
    }
    ascat_loci_gc {
        path "ascat/"
    }
    ascat_loci_rt {
        path "ascat/"
    }
    bowtie1_index {
        path "Sequence/BowtieIndex/1.3.1"
    }
    bowtie2_index {
        path "Sequence/Bowtie2Index/2.5.2"
    }
    bwamem1_index {
        path "Sequence/BWAIndex/0.7.18"
    }
    bwamem2_index {
        path "Sequence/BWAmem2Index/2.2.1"
    }
    chr_dir {
        path "Sequence/chr"
    }
    dragmap_hashmap {
        path "Sequence/dragmap/1.2.1"
    }
    fasta {
        path "Sequence/WholeGenomeFasta"
    }
    fasta_dict {
        path "Sequence/WholeGenomeFasta"
    }
    fasta_fai {
        path "Sequence/WholeGenomeFasta"
    }
    fasta_sizes {
        path "Sequence/WholeGenomeFasta"
    }
    gff {
        path "Annotation/Genes"
    }
    gtf {
        path "Annotation/Genes"
    }
    hisat2_index {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Sequence/Hisat2Index" + (meta.source_version == 'unknown' ? '' : meta.source_version + "/2.2.1")
        }
    }
    intervals_bed {
        path "Annotation/intervals"
    }
    kallisto_index {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Sequence/KallistoIndex" + (meta.source_version == 'unknown' ? '' : meta.source_version + "/0.51.1")
        }
    }
    msisensorpro_list {
        path "Annotation/msisensorpro"
    }
    rsem_index {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Sequence/RSEMIndex" + (meta.source_version == 'unknown' ? '' : meta.source_version + "/1.3.1")
        }
    }
    salmon_index {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Sequence/SalmonIndex" + (meta.source_version == 'unknown' ? '' : meta.source_version + "/1.10.3")
        }
    }
    snapaligner_index {
        path "Sequence/snap"
    }
    splice_sites {
        path "Sequence/SpliceSites"
    }
    star_index {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Sequence/STARIndex" + (meta.source_version == 'unknown' ? '' : meta.source_version + "/2.7.11b")
        }
    }
    transcript_fasta {
        path "Sequence/TranscriptFasta"
    }
    vcf_tbi {
        path { meta, file ->
            file >> "${meta.species}/${meta.source}/${meta.genome}/Annotation/${meta.source_vcf}/"
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Get workflow summary for MultiQC
//
def paramsSummaryMultiqc(summary_params) {
    def summary_section = ''
    summary_params
        .keySet()
        .each { group ->
            def group_params = summary_params.get(group)
            // This gets the parameters of that particular group
            if (group_params) {
                summary_section += "    <p style=\"font-size:110%\"><b>${group}</b></p>\n"
                summary_section += "    <dl class=\"dl-horizontal\">\n"
                group_params
                    .keySet()
                    .sort()
                    .each { param ->
                        summary_section += "        <dt>${param}</dt><dd><samp>${group_params.get(param) ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>\n"
                    }
                summary_section += "    </dl>\n"
            }
        }

    def yaml_file_text = "id: '${workflow.manifest.name.replace('/', '-')}-summary'\n" as String
    yaml_file_text += "description: ' - this information is collected when the pipeline is started.'\n"
    yaml_file_text += "section_name: '${workflow.manifest.name} Workflow Summary'\n"
    yaml_file_text += "section_href: 'https://github.com/${workflow.manifest.name}'\n"
    yaml_file_text += "plot_type: 'html'\n"
    yaml_file_text += "data: |\n"
    yaml_file_text += "${summary_section}"

    return yaml_file_text
}

// Helper function to check if a reference needs to be extracted
// Add the reference type to the meta
// Depending on the extension, return the appropriate channel
def need_extract(channel, type) {
    def with_reference = channel.map { meta, reference_ -> [meta + record(reference: type), reference_] }
    return [
        to_extract: with_reference.filter { _meta, reference_ -> reference_.toString().endsWith('.gz') || reference_.toString().endsWith('.zip') },
        not_extracted: with_reference.filter { _meta, reference_ -> !(reference_.toString().endsWith('.gz') || reference_.toString().endsWith('.zip')) },
    ]
}

// Helper function to check if a reference needs to be downloaded from ncbi
// Add the reference type to the meta
// Depending on the extension, return the appropriate channel
def need_ncbi_download(channel, type) {
    def with_reference = channel.map { meta, reference_ -> [meta + record(reference: type), reference_] }
    return [
        to_download: with_reference.filter { _meta, reference_ -> reference_.toString().contains('ncbi.nlm.nih.gov') },
        not_downloaded: with_reference.filter { _meta, reference_ -> !reference_.toString().contains('ncbi.nlm.nih.gov') },
    ]
}
