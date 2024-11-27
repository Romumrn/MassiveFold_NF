nextflow.enable.dsl=2

// Define the help message
def helpMessage = '''
Usage:
    nextflow run main.nf --sequence <path> --run <name> --predictions_per_model <int> --parameters <path> [options]

Required arguments:
    --sequence: path of the sequence(s) to infer, should be a 'fasta' file
    --run: name chosen for the run to organize in outputs.
    --predictions_per_model: number of predictions computed for each neural network model.
    --parameters: json file's path containing the parameters used for this run.

Optional arguments:
    --batch_size <int>: (default: 25) number of predictions per batch, should not be higher than --predictions_per_model.
    --calibration_from <path>: path of a previous run to calibrate the batch size from (see --calibrate).
    --wall_time <int>: (default: 20) total time available for calibration computations, unit is hours.
    --msas_precomputed <path>: path to directory that contains computed MSAs.
    --top_n_models <int>: uses the n neural network models with best ranking confidence from this run's path.
    --jobid <str>: job ID of an alignment job to wait for inference, skips the alignments.

Optional flags:
    --tool_to_use <str>: (default: 'AFmassive') Use either AFmassive or ColabFold in structure prediction for MassiveFold.
    --only_msas: only compute alignments, the first step of MassiveFold.
    --calibrate: calibrate --batch_size value. Searches from the previous runs for the same 'fasta' path given
                 in --sequence and uses the longest prediction time found to compute the maximal number of predictions per batch.
    --recompute_msas: purges previous alignment step and recomputes MSAs.

Example:
   nextflow main.nf --sequence example/H1140.fasta --run test --predictions_per_model 2 --parameters truc.json

'''

// Workflow definition
workflow {
    // Display the help message if requested
    if (params.help || params.h) {
        log.info(helpMessage)
        exit 0
    }

    // Validate required parameters
    if (!params.sequence || !params.run || !params.predictions_per_model || !params.parameters) {
        log.error("Missing required parameters.")
        log.info(helpMessage)
        exit 1
    }

    // Log inputs
    log.info("Sequence file: ${params.sequence}")
    log.info("Run name: ${params.run}")
    log.info("Tool choosen: ${params.tool}")
    // Declare input
    seqFile = file(params.sequence)
    runName = params.run

    // Invoke the process
    aligment(seqFile, runName, params.pair_strategy)
}


process aligment {
    container 'jysgro/colabfold:latest'

    input:
    path seqFile
    val runName
    val pair_strategy

    output:
    file("${runName}_results.txt")

    script:
    """
    if [[ ${pair_strategy} == "greedy" ]]; then
        pairing_strategy=0
    elif [[ ${pair_strategy} == "complete" ]]; then
        pairing_strategy=1
    else
        echo "ValueError: --pair_strategy '${pair_strategy}'"
        exit 1
    fi

    colabfold_search \
    $seqFile \
    data_dir \
    output_msa \
    --pairing_strategy \${pairing_strategy}
    """
}