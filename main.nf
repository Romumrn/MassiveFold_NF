nextflow.enable.dsl=2

// Define the help message
def helpMessage = '''
Usage:
    nextflow run main.nf --sequence <path(s)> --run <name> --predictions_per_model <int> --parameters <path> [options]

Required arguments:
    --sequence: path(s) of the sequence(s) to infer, should be a 'fasta' file or a list of files separated by commas.
    --run: name chosen for the run to organize outputs.
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
    nextflow main.nf --sequence example/H1140.fasta,example/H1141.fasta --run test --predictions_per_model 2 --parameters truc.json -profile docker

'''

// Workflow definition
workflow {
    // Display the help message if requested
    if (params.help || params.h) {
        log.info(helpMessage)
        exit 0
    }

    // Validate required parameters
    if (!params.sequence || !params.run || !params.predictions_per_model) {
        log.error("Missing required parameters.")
        log.info(helpMessage)
        exit 1
    }

    def seqFiles = files(params.sequence)
    def data_dir = params.data_dir 
    // def num_recycle =     params.num_recycle
    // def recycle_early_stop_tolerance = params.recycle_early_stop_tolerance
    // def max_seq =    params.max_seq

    // def disable_cluster_profile =    params.disable_cluster_profile
    // def use_dropout =    params.use_dropout

    // Log inputs
    log.info("Sequence files: ${seqFiles}")
    log.info("help: ${params.help}")
    log.info("h: ${params.h}")
    log.info("calibration: ${params.calibration}")
    log.info("predictions_per_model: ${params.predictions_per_model}")
    log.info("batch_size: ${params.batch_size}")
    log.info("wall_time: ${params.wall_time}")
    log.info("force_msas_computation: ${params.force_msas_computation}")
    log.info("only_msas: ${params.only_msas}")
    log.info("tool: ${params.tool}")
    log.info("model_preset: ${params.model_preset}")
    log.info("pair_strategy: ${params.pair_strategy}")
    log.info("use_dropout: ${params.use_dropout}")
    log.info("num_recycle: ${params.num_recycle}")

    // Invoke the alignment process
    def msa_results = RUN_alignment(seqFiles, params.run, params.data_dir, params.pair_strategy )

    // Process batches and run inference
    // def batched_sequences = msa_results
    //     .groupTuple(size: params.batch_size ?: 25)
    //     .map { batch, index -> tuple(index, batch) }

    // batched_sequences | run_inference( params.run, params)
    RUN_inference_no_batch( 
        msa_results, 
        params.run,
        data_dir , 
        params.num_recycle, 
        params.recycle_early_stop_tolerance,
        params.use_dropout)
    }

process RUN_FAKE_alignment {
    container 'jysgro/colabfold:latest'
    tag "$seqFile.baseName"

    input:
    path(seqFile)
    val(runName)
    path(data_dir)
    val(pair_strategy)

    output:
    tuple val(seqFile.baseName), path("${seqFile.baseName}_msa*")

    script:
    """
    
    cp -r /home/ubuntu/MassiveFold_NF/output_msa  ./${seqFile.baseName}_msa 
    """
}

process RUN_alignment {
    container 'jysgro/colabfold:latest'
    tag "$seqFile.baseName"

    input:
    path(seqFile)
    val(runName)
    path(data_dir)
    val(pair_strategy)

    output:
    tuple val(seqFile.baseName), path("${seqFile.baseName}_msa*")

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

    time colabfold_search $seqFile $data_dir ${seqFile.baseName}_msa --pairing_strategy \${pairing_strategy}
    """
}


process RUN_inference_no_batch {
    container 'jysgro/colabfold:latest'

    input:
    tuple val(sequence_name), path(msaFolder)
    val(run_name)
    val(data_dir)
    val(num_recycle)
    val(recycle_early_stop_tolerance)
    val(use_dropout)

    output:
    path("*")

    script:
    """
    sequence_name=${sequence_name}
    run_name=${run_name}
    fafile=${msaFolder}/${sequence_name}.fasta
    data_dir=${data_dir}

    num_recycle=${num_recycle}
    recycle_early_stop_tolerance=${recycle_early_stop_tolerance}
    BOOL_use_dropout=${use_dropout}

    if \${BOOL_use_dropout}; then
        echo "Parameter --use-dropout set"
        use_dropout="--use-dropout"
    fi

    time colabfold_batch
      ${msaFolder}/
      res_${sequence_name}_${run_name}
      --data ${data_dir}
      --save-all
      --random-seed \${random_seed}
      --num-seeds \${num_seeds}
      --model-type \${model_type}
      --model-order \${num_models}
      --num-models 1
    """
}
