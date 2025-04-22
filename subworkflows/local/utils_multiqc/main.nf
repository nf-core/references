include { MULTIQC } from '../../../modules/nf-core/multiqc'

workflow UTILS_MULTIQC {
    take:
    path_multiqc_config
    params_multiqc_config
    params_multiqc_logo
    ch_workflow_summary
    ch_methods_description
    ch_versions

    main:
    // All the files and meta data are contained in the meta map (except for fasta)

    ch_multiqc_files = Channel.empty()

    // MODULE: MultiQC
    ch_multiqc_config = Channel.fromPath(path_multiqc_config, checkIfExists: true)
    ch_multiqc_custom_config = params_multiqc_config ? Channel.fromPath(params_multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo = params_multiqc_logo ? Channel.fromPath(params_multiqc_logo, checkIfExists: true) : Channel.empty()

    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_versions)
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
