# nf-core/references: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/references/usage](https://nf-co.re/references/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

<!-- TODO nf-core: Add documentation about anything specific to running your pipeline. For general topics, please point to (and add to) the main nf-core website. -->

## Tools selection

The pipeline supports a flexible tools selection system with three parameters that work together:

### `--tools_bundle`

Select a predefined bundle of tools. Available bundles:

| Bundle   | Tools                                                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `all`    | All available tools                                                                                                                  |
| `rnaseq` | bowtie1, bowtie2, faidx, gffread, hisat2, hisat2_extractsplicesites, kallisto, rsem, rsem_make_transcript_fasta, salmon, sizes, star |
| `sarek`  | bwamem1, bwamem2, createsequencedictionary, dragmap, faidx, intervals, msisensorpro, snapaligner, tabix                              |
| `null`   | None. No tool indices will be built. Useful when you only need the genome and annotation files without building any indices.         |

```bash
# Build all RNA-seq references
--tools_bundle rnaseq

# Build all Sarek references
--tools_bundle sarek

# Build everything
--tools_bundle all

# Download genome/annotation only, no tool indices
--tools_bundle null
```

### `--tools`

Add individual tools on top of a bundle (or use standalone without a bundle):

```bash
# Add extra tools on top of a bundle
--tools_bundle rnaseq --tools star,salmon

# Use standalone without a bundle
--tools star,salmon,bwamem2
```

### `--skip_tools`

Remove specific tools from the final selection (overrides bundles and `--tools`):

```bash
# Build all RNA-seq references except hisat2 and kallisto
--tools_bundle rnaseq --skip_tools hisat2,kallisto

# Build everything except dragmap and tabix
--tools_bundle all --skip_tools dragmap,tabix
```

## HISAT2 index options

### `--hisat2_skip_splice_sites`

HISAT2 normally includes splice sites and exons in the index for eukaryotic genomes. Use this flag to skip splice site extraction for prokaryotic genomes like _E. coli_:

```bash
--tools hisat2 --hisat2_skip_splice_sites
```

Without this flag, the pipeline tries to extract splice sites from the GTF and pass them to `hisat2-build`. For prokaryotic genomes with no introns, this produces an empty splice sites file and HISAT2 fails. This flag skips that step.

### `--hisat2_build_memory`

Set the memory threshold for splice-aware indexing:

```bash
--hisat2_build_memory '100.GB'
```

When process memory is at least this threshold, HISAT2 uses splice sites and exons. Below it, HISAT2 builds the index without splice information.

## STAR index options

### `--star_sjdbOverhang`

Length of donor and acceptor splice site anchors for the STAR splice junction database.

Default behaviour: STAR auto-calculates this from read length.

Typical values:

- 99 bp for mammals with 100 bp reads
- 74 bp for insects
- 50-100 bp for plants
- 1 bp less than read length (general rule)

Set a fixed value with:

```bash
--tools star --star_sjdbOverhang 99
```

### `--star_genomeSAindexNbases`

Length of the suffix array pre-indexing string. Larger values use more memory during indexing but produce smaller indices.

Default behaviour: STAR calculates this as `log2(genome_size)/2 - 1`, capped at 14.

Typical values:

- 14 for large genomes (>500 Mb)
- 11 for compact genomes (<300 Mb)

Set a specific value with:

```bash
--tools star --star_genomeSAindexNbases 14
```

### Per-genome STAR parameters

Specify `star_sjdbOverhang` and `star_genomeSAindexNbases` per genome in your YAML asset file:

```yaml
- genome: GRCh38
  species: Homo_sapiens
  fasta: https://example.com/GRCh38.fa
  gtf: https://example.com/GRCh38.gtf
  star_sjdbOverhang: 99
  star_genomeSAindexNbases: 14
```

Parameter precedence (highest to lowest):

1. CLI parameters (`--star_sjdbOverhang`, `--star_genomeSAindexNbases`)
2. Per-genome parameters in YAML
3. STAR defaults (auto-calculated)

## Asset input

You will need to create an asset yaml file with information about the genome(s) and files to use for building references before running the pipeline.
Use this parameter to specify its location.
It has to be a yaml file.

```bash
--input '[path to asset file]'
```

### Multiple genomes

A datasheet is a YAML list with one entry per genome. `genome` is the only required field, and every other field applies to the entry it sits in:

```yaml
- genome: GRCh38_chr21
  species: Homo_sapiens
  source: nf-core
  fasta: https://raw.githubusercontent.com/nf-core/test-datasets/references/references/GRCh38_chr21/GRCh38_chr21.fa

- genome: GRCh38_chr22
  species: Homo_sapiens
  source: nf-core
  fasta: https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/genome/genome.fasta
```

Set `species` and `source` on every entry. The pipeline builds the published path from `species/source/genome`, so each entry writes into its own tree and one run can build several genomes without collisions:

```text
Homo_sapiens/nf-core/GRCh38_chr21/Sequence/WholeGenomeFasta/
Homo_sapiens/nf-core/GRCh38_chr22/Sequence/WholeGenomeFasta/
```

The pipeline computes run flags per entry, so genomes build independently. It skips annotation-dependent tools for an entry that has neither `gtf` nor `gff`.

### Full asset file

An entry lists what a genome already provides. Only `genome` is required; the pipeline builds the rest from `fasta` and `gff` or `gtf`:

```yaml
- genome: GRCh37
  species: Homo_sapiens
  source: GATK

  # Genome and annotation
  fasta: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Sequence/WholeGenomeFasta/human_g1k_v37_decoy.fasta
  fasta_fai: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Sequence/WholeGenomeFasta/human_g1k_v37_decoy.fasta.fai
  fasta_dict: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Sequence/WholeGenomeFasta/human_g1k_v37_decoy.dict

  # A prebuilt index, used exactly as supplied
  bwamem1_index: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Sequence/BWAIndex/

  # A GATK resource VCF, with its tabix index and its provenance
  vcf_dbsnp_vcf: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Annotation/GATKBundle/dbsnp_138.b37.vcf.gz
  vcf_dbsnp_vcf_tbi: s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh37/Annotation/GATKBundle/dbsnp_138.b37.vcf.gz.tbi
  vcf_dbsnp_vcf_source: GATKBundle
```

Format rules:

- Supply an artefact and the pipeline skips building it. `fasta_fai`, `fasta_dict`, `bwamem1_index`, `star_index`, `hisat2_index`, and the other index fields work this way, so one entry can mix built and provided assets.
- The `vcf_*_vcf` fields accept a single path or a list. A matching `vcf_*_vcf_tbi` list pairs by position, and a `null` entry means the pipeline builds that index.
- The `*_source` fields record provenance and become the `Annotation/<source>` segment of the published path.
- Any path may carry a `${params.references_base_path}` placeholder (see `--references_base_path`).
- A field that is not in `subworkflows/local/utils_references/schema_references.json` is ignored with a warning, so check that file for the complete list.

Example asset files are published in the [nf-core/references-datasheets](https://github.com/nf-core/references-datasheets) repository.

### `--references_base_path`

A datasheet path may carry a `${params.references_base_path}` placeholder instead of a hardcoded root:

```yaml
- genome: GRCh38_chr21
  fasta: ${params.references_base_path}/GRCh38_chr21/GRCh38_chr21.fa
```

The pipeline substitutes the parameter into the path as the datasheet loads, so one datasheet can be used against any mirror of the reference files:

```bash
--references_base_path '/data/mirror/igenomes'
```

The default is `s3://ngi-igenomes/igenomes`, the root that published datasheets are written against. With that default the example above resolves to `s3://ngi-igenomes/igenomes/GRCh38_chr21/GRCh38_chr21.fa`.

The placeholder carries the leading slash, so the value must not end with one. A trailing slash produces a doubled slash in the path.

Datasheets without placeholders are unchanged and need no edit. This parameter only rewrites paths inside the datasheet; the location of the datasheet itself is set with `--input`.

### Reference selection in consuming pipelines

A pipeline that consumes references resolves them from the first source that supplies a usable record. Any source may contribute any subset of keys, such as `fasta`, `fasta_fai`, `genome`, or `species`:

- Explicit parameters, for example `--fasta` and `--fasta_fai`.
- A references datasheet, passed as a file, or located from a base URL plus a genome key.
- An iGenomes catalogue entry for the selected `--genome`.

Each source runs only when the previous ones did not supply `fasta`, so an explicit parameter prevents an unnecessary datasheet fetch. Selecting a datasheet and selecting a catalogue entry at the same time is an error: the sources are mutually exclusive, and pipelines reject the combination rather than guess an order.

Parameter names for these sources belong to each consuming pipeline and are documented in its own usage pages. nf-core/bamtofastq, for example, selects the datasheet with `--references` and the catalogue with `--genome` plus `--igenomes_ignore`, and points back here for this shared resolution order.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/references --input ./asset.yml --outdir ./results  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/references -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/references
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/references releases page](https://github.com/nf-core/references/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow `24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
