nextflow.enable.dsl = 2

// Define the help message
def helpMessage = '''
Usage:
    nextflow main.nf --sequence example/H1140.fasta --run test --database_dir ~/data/public/colabfold/ -profile docker
Required arguments:
    --sequence: path(s) of the sequence(s) to infer, should be a 'fasta' file or a list of files separated by commas.
    --run: name chosen for the run to organize outputs.
    --database_dir : ~/data/public/colabfold

Optional arguments:
    --parameters: json file's path containing the parameters used for this run.
    --predictions_per_model: number of predictions computed for each neural network model.
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
    ./nextflow main.nf --sequence example/H1140.fasta --run test --database_dir ~/data/public/colabfold/ -profile docker -resume
'''

workflow {
    // Display the help message if requested
    if (params.help || params.h) {
        log.info(helpMessage)
        exit 0
    }

    // Validate required parameters
    if (!params.sequence || !params.run || !params.database_dir) {
        log.error('Missing required parameters.')
        log.info(helpMessage)
        exit 1
    }

    def seqFiles = files(params.sequence)

    // Log inputs
    log.info("Sequence files: ${seqFiles}")

    def msa_results
    if (params.msas_precomputed) {
        // Use precomputed alignments
        log.info("Using precomputed MSAs: ${params.msas_precomputed}")
        log.info('Skipping alignment step as precomputed alignments are provided.')
        msa_results = Channel
            .fromPath(params.msas_precomputed)
            .map { precomputed_msa -> tuple(precomputed_msa.baseName, precomputed_msa) }
        
    } else {
        // Run alignment process
        msa_results = RUN_alignment(seqFiles, params.run, params.database_dir, params.pair_strategy)
    }

    // Generate the batches channel (seqname, json_path)
    batches_csv = Create_batchs_csv(msa_results, params.predictions_per_model, params.batch_size, "ColabFold", "", params.bash_script)

    //batches_csv.splitCsv( header: true ).view()

    RUN_inference(
            batches_csv.splitCsv( header: true ),
            msa_results,
            params.run,
            params.database_dir,
            params.num_recycle,
            params.recycle_early_stop_tolerance,
            params.use_dropout
        )

    // // Pass the results to the inference step
    // RUN_inference_no_batch(
    //     batch
    //     msa_results,
    //     batches_data,
    //     params.run,
    //     params.database_dir,
    //     params.num_recycle,
    //     params.recycle_early_stop_tolerance,
    //     params.use_dropout
    // )
}

process RUN_alignment {
    container 'jysgro/colabfold:latest'
    tag "$seqFile.baseName"
    publishDir "result/$runName/alignment"

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


process Create_batchs_csv {
    tag "$sequence_name"

    input:
    tuple val(sequence_name), path(msaFolder)
    val(predictions_per_model)
    val(batch_size)
    val(tool)
    val(models_to_use)
    path(script)

    output:
    path("${sequence_name}_batches.csv")  //Output JSON file with batch details

    script:
    """
    python3 create_batches_csv.py $predictions_per_model $batch_size "$models_to_use" "$sequence_name" "$tool"
    """
}

// process RUN_inference_no_batch {
//     tag "$sequence_name"
//     container 'jysgro/colabfold:latest'

//     publishDir "result/$runName/prediction"

//     input:
//     tuple val(sequence_name), path(msaFolder)
//     val(run_name)
//     path(data_dir)
//     val(num_recycle)
//     val(recycle_early_stop_tolerance)
//     val(use_dropout)

//     output:
//     path('*')

//     script:
//     """
//     export JAX_PLATFORMS=cpu
//     sequence_name=${sequence_name}
//     run_name=${run_name}
//     fafile=${msaFolder}/${sequence_name}.fasta
//     num_recycle=${num_recycle}
//     recycle_early_stop_tolerance=${recycle_early_stop_tolerance}
//     BOOL_use_dropout=${use_dropout}

//     if \${BOOL_use_dropout}; then
//         echo "Parameter --use-dropout set"
//         use_dropout="--use-dropout"
//     fi

//     time colabfold_batch \
//       --data ${data_dir} \
//       --save-all \
//       --random-seed 42 \
//       --num-models 1 \
//       ${msaFolder} \
//       res_${sequence_name}_${run_name}
//     """
// }

process RUN_inference {
    tag { id  }
    container 'jysgro/colabfold:latest'

    publishDir "result/$runName/prediction"

    input:
    tuple val(id_batch), val(sequence_name), val(batch_start), val(batch_end), val(batch_model)
    path(msaFolder)
    val(run_name)
    path(data_dir)
    val(num_recycle)
    val(recycle_early_stop_tolerance)
    val(use_dropout)

    output:
    path("*")

    script:
    """
    echo $batch_model
    num_models=\$(echo $batch_model | cut -d "_" -f 2)
    echo "using model $num_models"
    num_version=\$(echo $batch_model | cut -d "v" -f 2)
    version_type="alphafold2_multimer_v$num_version"
    model_type=$version_type
    echo "from version version $model_type"
    num_seeds=\$(($batch_end - $batch_start + 1))
    echo "predictions computed in the batch: $num_seeds"

    colabfold_batch \
    ${msaFolder} \
      res_${sequence_name}_${run_name}_${id_batch} \
    --data ${data_dir} \
    --save-all \
    --random-seed $random_seed \
    --num-seeds $num_seeds \
    --model-type $model_type \
    --model-order $num_models \
    --num-models 1 \
    --num-recycle $num_recycle \
    --recycle-early-stop-tolerance $recycle_early_stop_tolerance \
    --stop-at-score $stop_at_score \
    $use_dropout \
    $disable_cluster_profile
    """
}
