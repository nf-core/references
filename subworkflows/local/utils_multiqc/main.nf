include { MULTIQC            } from '../../../modules/nf-core/multiqc'
include { getWorkflowVersion } from '../../nf-core/utils_nfcore_pipeline'

workflow UTILS_MULTIQC {
    take:
    path_multiqc_config
    params_multiqc_config
    params_multiqc_logo
    ch_workflow_summary_input
    ch_methods_description
    ch_versions
    pipeline_name

    main:
    // All the files and meta data are contained in the meta map (except for fasta)

    ch_multiqc_files = Channel.empty()

    // MODULE: MultiQC
    ch_multiqc_config = Channel.fromPath(path_multiqc_config, checkIfExists: true)
    ch_multiqc_custom_config = params_multiqc_config ? Channel.fromPath(params_multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo = params_multiqc_logo ? Channel.fromPath(params_multiqc_logo, checkIfExists: true) : Channel.empty()
    ch_versions_yaml = softwareVersionsToYAML(ch_versions).collectFile(storeDir: "${params.outdir}/pipeline_info", name: "${pipeline_name}_software_mqc_versions.yml", sort: true, newLine: true)
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(ch_workflow_summary_input))

    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_versions_yaml)
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    data   = MULTIQC.out.data
    plots  = MULTIQC.out.plots
    report = MULTIQC.out.report
}

//
// Get software versions for pipeline
//
def processVersionsFromYAML(yaml_file) {
    def yaml = new org.yaml.snakeyaml.Yaml()
    def versions = yaml.load(yaml_file).collectEntries { k, v -> [k.tokenize(':')[-1], v] }
    return yaml.dumpAsMap(versions).trim()
}

//
// Get workflow version for pipeline
//
def workflowVersionToYAML() {
    return """
    Workflow:
        ${workflow.manifest.name}: ${getWorkflowVersion()}
        Nextflow: ${workflow.nextflow.version}
    """.stripIndent().trim()
}

//
// Get channel of software versions used in pipeline in YAML format
//
def softwareVersionsToYAML(ch_versions) {
    return ch_versions.unique().map { version -> processVersionsFromYAML(version) }.unique().mix(Channel.of(workflowVersionToYAML()))
}

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
