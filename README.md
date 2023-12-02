Some thoughts on reference building:

- We could use the glob and if you just drop a fasta in s3 bucket it'll get picked up and new resources built
  - Could take this a step further and make it a little config file that has the fasta, gtf, genome_size etc.
- How do we avoid rebuilding? Ideally we should build once on a new minor release of an aligner/reference. IMO kinda low priority because the main cost is going to be egress, not compute.
- How much effort is too much effort?
  - Should it be as easy as adding a file on s3?
    - No that shouldn't be a requirement, should be able to link to a reference externally(A "source of truth" ie an FTP link), and the workflow will build the references
    - So like mulled biocontainers, just make a PR to the samplesheet and boom new reference in the s3 bucket if it's approved?

# Roadmap

PoC:

- Replace aws-igenomes
  - bwa, bowtie2, star, bismark need to be built
  - fasta, gtf, bed12, mito_name, macs_gsize blacklist, copied over

Other nice things to have:

- Building our test-datasets
- Downsampling for a unified genomics test dataset creation, (Thinking about viralitegration/rnaseq/wgs) and spiking in test cases of interest(Specific variants for example)
