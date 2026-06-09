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
    tuple val(meta), path("*enomic.fna"), emit: fna, optional: true
    tuple val(meta), path("*enomic.gff"), emit: gff, optional: true
    tuple val(meta), path("*enomic.gtf"), emit: gtf, optional: true
    tuple val("${task.process}"), val('ncbidatasetscli'), eval('datasets --version | sed "s/datasets version: //"'), topic: versions, emit: versions_ncbidatasetscli
    tuple val("${task.process}"), val('gunzip'), eval('gunzip --version 2>&1 | head -1 | sed "s/^.*(gzip) //; s/ Copyright.*//"'), topic: versions, emit: versions_gunzip

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    datasets ${args} \\
        download \\
        genome accession ${meta.accession} \\
        --reference --include ${reference}
    7za \\
        x \\
        -o"data"/ \\
        ncbi_dataset.zip

    mv data/ncbi_dataset/data/${meta.accession}/* .
    """
}
