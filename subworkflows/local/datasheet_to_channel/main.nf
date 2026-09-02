workflow DATASHEET_TO_CHANNEL {
    take:
    datasheet // channel: [meta, fasta]
    tools // List: Can contain any combination of tools of the list of available tools, or just no_tools

    main:
    // All the files and meta data are contained in the meta map (except for fasta)
    // They are extracted out of the meta map in their own channel in this subworkflow
    // When adding a new field in the utils_references/schema_references.json, also add it in the meta map
    // And in this script, add a new branch and a new output corresponding to this input
    // And in the emit, add the new output to the channel

    ascat_alleles = datasheet
        .filter { meta, _readme -> meta.ascat_alleles }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.ascat_alleles, checkIfExists: true)] }

    ascat_loci = datasheet
        .filter { meta, _readme -> meta.ascat_loci }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.ascat_loci, checkIfExists: true)] }

    ascat_loci_gc = datasheet
        .filter { meta, _readme -> meta.ascat_loci_gc }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.ascat_loci_gc, checkIfExists: true)] }

    ascat_loci_rt = datasheet
        .filter { meta, _readme -> meta.ascat_loci_rt }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.ascat_loci_rt, checkIfExists: true)] }

    chr_dir = datasheet
        .filter { meta, _readme -> meta.chr_dir }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.chr_dir, checkIfExists: true)] }

    intervals_bed = datasheet
        .filter { meta, _readme -> meta.intervals_bed }
        .map { meta, _readme -> [reduceMeta(meta), file(meta.intervals_bed, checkIfExists: true)] }

    fasta = datasheet
        .filter { meta, _readme -> meta.fasta }
        .map { meta, _readme ->
            def meta_extra = record(run_bowtie1: meta.bowtie1_index ? false : true)
            meta_extra += record(run_bowtie2: meta.bowtie2_index ? false : true)
            meta_extra += record(run_bwamem1: meta.bwamem1_index ? false : true)
            meta_extra += record(run_bwamem2: meta.bwamem2_index ? false : true)
            meta_extra += record(run_createsequencedictionary: meta.fasta_dict ? false : true)
            meta_extra += record(run_dragmap: meta.dragmap_hashtable ? false : true)
            meta_extra += record(run_faidx: meta.fasta_fai && (meta.fasta_sizes || !('sizes' in tools)) ? false : true)
            meta_extra += record(run_hisat2: meta.hisat2_index ? false : true)
            meta_extra += record(run_intervals: meta.intervals_bed ? false : true)
            meta_extra += record(run_kallisto: meta.kallisto_index ? false : true)
            meta_extra += record(run_msisensorpro: meta.msisensorpro_list ? false : true)
            meta_extra += record(run_rsem: meta.rsem_index ? false : true)
            meta_extra += record(run_rsem_make_transcript_fasta: meta.transcript_fasta ? false : true)
            meta_extra += record(run_salmon: meta.salmon_index ? false : true)
            meta_extra += record(run_star: meta.star_index ? false : true)
            meta_extra += record(run_snapaligner: meta.snapaligner_index ? false : true)
            [reduceMeta(meta) + meta_extra, meta.fasta.contains('ncbi.nlm.nih.gov') ? meta.fasta : file(meta.fasta, checkIfExists: true)]
        }

    fasta_dict = datasheet
        .filter { meta, _readme -> meta.fasta_dict }
        .map { meta, _readme -> [reduceMeta(meta), meta.fasta_dict] }

    fasta_fai = datasheet
        .filter { meta, _readme -> meta.fasta_fai }
        .map { meta, _readme ->
            def meta_extra = record(run_intervals: meta.intervals_bed ? false : true)
            [reduceMeta(meta) + meta_extra, file(meta.fasta_fai, checkIfExists: true)]
        }

    fasta_sizes = datasheet
        .filter { meta, _readme -> meta.fasta_sizes }
        .map { meta, _readme -> [reduceMeta(meta), meta.fasta_sizes] }

    gff = datasheet
        .filter { meta, _readme -> meta.gff }
        .map { meta, _readme ->
            def meta_extra = record(run_gffread: meta.fasta && !meta.gtf ?: false)
            meta_extra += record(run_hisat2: meta.splice_sites ? false : true)
            [reduceMeta(meta) + meta_extra, meta.gff.contains('ncbi.nlm.nih.gov') ? meta.gff : file(meta.gff, checkIfExists: true)]
        }

    gtf = datasheet
        .filter { meta, _readme -> meta.gtf }
        .map { meta, _readme ->
            def meta_extra = record(run_hisat2: meta.splice_sites ? false : true)
            [reduceMeta(meta) + meta_extra, meta.gtf.contains('ncbi.nlm.nih.gov') ? meta.gtf : file(meta.gtf, checkIfExists: true)]
        }

    splice_sites = datasheet
        .filter { meta, _readme -> meta.splice_sites }
        .map { meta, _readme -> [reduceMeta(meta), meta.splice_sites] }

    transcript_fasta = datasheet
        .filter { meta, _readme -> meta.transcript_fasta }
        .map { meta, _readme ->
            def meta_extra = record(run_hisat2: meta.hisat2_index ? false : true)
            meta_extra += record(run_kallisto: meta.kallisto_index ? false : true)
            meta_extra += record(run_rsem: meta.rsem_index ? false : true)
            meta_extra += record(run_salmon: meta.salmon_index ? false : true)
            meta_extra += record(run_star: meta.star_index ? false : true)
            [reduceMeta(meta) + meta_extra, file(meta.transcript_fasta, checkIfExists: true)]
        }

    // HANDLING OF VCF

    dbsnp = datasheet
        .filter { meta, _readme -> meta.vcf_dbsnp_vcf }
        .map { meta, _readme ->
            def meta_extra = record(run_tabix: !meta.vcf_dbsnp_vcf_tbi)
            meta_extra += record(type: 'dbsnp', source_vcf: meta.vcf_dbsnp_vcf_source)
            [reduceMeta(meta) + meta_extra, files(meta.vcf_dbsnp_vcf, checkIfExists: true)]
        }

    germline_resource = datasheet
        .filter { meta, _readme -> meta.vcf_germline_resource_vcf }
        .map { meta, _readme ->
            def meta_extra = record(run_tabix: !meta.vcf_germline_resource_vcf_tbi)
            meta_extra += record(type: 'germline_resource', source_vcf: meta.vcf_germline_resource_vcf_source)
            [reduceMeta(meta) + meta_extra, file(meta.vcf_germline_resource_vcf, checkIfExists: true)]
        }

    known_indels = datasheet
        .filter { meta, _readme -> meta.vcf_known_indels_vcf }
        .map { meta, _readme ->
            def meta_extra = record(run_tabix: !meta.vcf_known_indels_vcf_tbi)
            meta_extra += record(type: 'known_indels', source_vcf: meta.vcf_known_indels_vcf_source)
            [reduceMeta(meta) + meta_extra, file(meta.vcf_known_indels_vcf, checkIfExists: true)]
        }

    known_snps = datasheet
        .filter { meta, _readme -> meta.vcf_known_snps_vcf }
        .map { meta, _readme ->
            def meta_extra = record(run_tabix: !meta.vcf_known_snps_vcf_tbi)
            meta_extra += record(type: 'known_snps', source_vcf: meta.vcf_known_snps_vcf_source)
            [reduceMeta(meta) + meta_extra, file(meta.vcf_known_snps_vcf, checkIfExists: true)]
        }

    pon = datasheet
        .filter { meta, _readme -> meta.vcf_pon_vcf }
        .map { meta, _readme ->
            def meta_extra = record(run_tabix: !meta.vcf_pon_vcf_tbi)
            meta_extra += record(type: 'pon', source_vcf: meta.vcf_pon_vcf_source)
            [reduceMeta(meta) + meta_extra, file(meta.vcf_pon_vcf, checkIfExists: true)]
        }

    vcf = channel.empty()
        .mix(
            dbsnp,
            germline_resource,
            known_indels,
            known_snps,
            pon,
        )
        .transpose()

    emit:
    ascat_alleles    = ascat_alleles // channel: [meta, *.ascat_alleles.txt]
    ascat_loci       = ascat_loci // channel: [meta, *.ascat_loci.txt]
    ascat_loci_gc    = ascat_loci_gc // channel: [meta, *.ascat_loci_gc.txt]
    ascat_loci_rt    = ascat_loci_rt // channel: [meta, *.ascat_loci_rt.txt]
    chr_dir          = chr_dir // channel: [meta, *.chr_dir]
    intervals_bed    = intervals_bed // channel: [meta, *.bed]
    fasta            = fasta // channel: [meta, *.f(ast|n)?a]
    fasta_dict       = fasta_dict // channel: [meta, *.f(ast|n)?a.dict]
    fasta_fai        = fasta_fai // channel: [meta, *.f(ast|n)?a.fai]
    fasta_sizes      = fasta_sizes // channel: [meta, *.f(ast|n)?a.sizes]
    gff              = gff // channel: [meta, gff]
    gtf              = gtf // channel: [meta, gtf]
    splice_sites     = splice_sites // channel: [meta, *.splice_sites.txt]
    transcript_fasta = transcript_fasta // channel: [meta, *.transcripts.fasta]
    vcf              = vcf // channel: [meta, *.vcf.gz]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UTILITY FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Only keep the actual meta data in the meta map
// Add a field here if it is a relevant meta data
def reduceMeta(meta_) {
    record(
        id: meta_.id,
        genome: meta_.genome,
        source: meta_.source,
        source_version: meta_.source_version,
        species: meta_.species,
    )
}
