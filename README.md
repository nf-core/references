Some thoughts on reference building:

- We could use the glob and if you just drop a fasta in s3 bucket it'll get picked up and new resources built
  - Could take this a step further and make it a little config file that has the fasta, gtf, genome_size etc.
- How do we avoid rebuilding? Ideally we should build once on a new minor release of an aligner/reference. IMO kinda low priority because the main cost is going to be egress, not compute.

# Roadmap

PoC:

- Replace aws-igenomes
  - bwa, bowtie2, star, bismark need to be built
  - fasta, gtf, bed12, mito_name, macs_gsize blacklist, copied over

Other nice things to have:

- Building our test-datasets
- Downsampling for a unified genomics test dataset creation, (Thinking about viralitegration/rnaseq/wgs) and spiking in test cases of interest(Specific variants for example)
