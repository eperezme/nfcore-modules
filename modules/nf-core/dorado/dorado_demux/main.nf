process DORADO_DEMUX {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'docker.io/eperezme/dorado:nano' }"

    input:
    tuple val(meta), path("*.bam"),
    tuple val(meta), path("*.fastq")

    output:
    tuple val(meta), path("*_demux.bam"), emit: bam
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // If kit is specified, pass it to dorado
    if (params.kit) {
        kit = "--kit-name $params.kit"
    }

    def additional_args = ""
    if (params.no_classify) {
        additional_args += "--no-classify"
    }
    if (params.barcode_both_ends) {
        additional_args += "--barcode-both-ends"
    }
    if (params.emit_demux_summary) {
        additional_args += "--emit-summary"
    }
    

    """
    // Run the dorado basecaller with the specified mode and arguments
    dorado demux $kit --output-dir $prefix $args $additional_args $input

    // Create a versions.yml file with the dorado version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(echo \$(dorado --version 2>&1) | sed -r 's/.{81}//')
    END_VERSIONS
    """
}
