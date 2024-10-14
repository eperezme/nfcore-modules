process DORADO_BASECALLER {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'docker.io/eperezme/dorado:nano' }"

    input:
    tuple val(meta), path("*.pod5")

    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.fastq"), emit: fastq
    tuple val(meta), path("summary.tsv"), emit: summary
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Determine the mode based on the duplex parameter
    def mode = (params.duplex == true) ? "duplex" : "basecaller"

    // MODEL selection and modified bases handling
    if (params.modified_bases) {
        def dorado_model = "$params.model,$params.modified_bases"
    } else {
        def dorado_model = "$params.model"
    }

    // EMISION ARGS: Initialize emit_args based on parameters
    def emit_args = ""
    if (params.error_correction == true || params.emit_fastq == true) {
        emit_args = "basecall.fastq && gzip basecall.fastq"
    } 
    // Emit BAM if emit_bam is true or modified_bases is true
    // Demultiplexing with kit name, output will be in bam
    elif (params.emit_bam == true || params.modified_bases || (params.demultiplexing && params.kit)) {
        emit_args = "basecall.bam"
    }

    //ALIGNMENT
    // Initialize additional_args based on parameters
    def additional_args = ""
    if (params.align) {
       additional_args += " --reference $params.ref_genome --mm2-opt '-k $params.kmer_size -w $params.win_size'" 
    }
    //TRIMMING 
    // Handle trimming options
    if (params.demultiplexing && params.kit) {
        additional_args += " --no-trim"
    } 
    elif (params.trim) {
        additional_args += " --trim $params.trim"
    }
    if (params.kit) {
        additional_args += " --kit-name $params.kit"
    }

    """
    // Run the dorado basecaller with the specified mode and arguments
    dorado $mode $dorado_model $additional_args $pod5_path > $emit_args

    // Create the summary file
    dorado summary $emit_args > summary.tsv

    // Create a versions.yml file with the dorado version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(echo \$(dorado --version 2>&1) | sed -r 's/.{81}//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """
}
