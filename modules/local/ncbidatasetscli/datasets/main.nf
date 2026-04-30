process NCBIDATASETSCLI_DATASETS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/1a/1aa4bda9c572b2003c96a5710c07d6d793f96fdea0336fa5c750be2da2e8aed6/data'
        : 'community.wave.seqera.io/library/ncbi-datasets-cli_p7zip:f0c05932b8712591'}"

    input:
    tuple val(meta), val(reference)

    output:
    tuple val(meta), path("*enomic.gbff"), emit: gbk, optional: true
    tuple val(meta), path("*enomic.fna"), emit: fna, optional: true
    tuple val(meta), path("*_rm.out"), emit: rm, optional: true
    tuple val(meta), path("*_feature_table.txt"), emit: features, optional: true
    tuple val(meta), path("*enomic.gff"), emit: gff, optional: true
    tuple val(meta), path("*enomic.gtf"), emit: gtf, optional: true
    tuple val(meta), path("*rotein.faa"), emit: faa, optional: true
    tuple val(meta), path("*rotein.gpff"), emit: gpff, optional: true
    tuple val(meta), path("*_wgsmaster.gbff"), emit: wgs_gbk, optional: true
    tuple val(meta), path("*_cds_from_genomic.fna"), emit: cds, optional: true
    tuple val(meta), path("*_rna.fna"), emit: rna, optional: true
    tuple val(meta), path("*_rna_from_genomic.fna"), emit: rna_fna, optional: true
    tuple val(meta), path("*_assembly_report.txt"), emit: report, optional: true
    tuple val(meta), path("*_assembly_stats.txt"), emit: stats, optional: true
    tuple val("${task.process}"), val('ncbidatasetscli'), eval('datasets --version'), topic: versions, emit: versions_ncbidatasetscli

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    datasets download genome accession ${meta.accession} --reference --include ${reference}
    7za \\
        x \\
        -o"data"/ \\
        ncbi_dataset.zip

    mv data/ncbi_dataset/data/${meta.accession}/* .
    """
}
