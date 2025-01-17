# MassiveFold_NF  

The goal of this project is to transform [MassiveFold](https://github.com/GBLille/MassiveFold) into a **Nextflow pipeline**. Currently, MassiveFold can only run on a SLURM server, which is a significant limitation. To overcome this, the objective is to create a workflow with Nextflow that can run on various platforms, including local machines, cloud environments, and clusters, using a dedicated configuration.  

Nextflow offers several advantages, such as scalability, reproducibility, and the ability to run workflows seamlessly across different computing infrastructures.  One of the big advante is that you can run each step into a container that allow a good reprocibily of your analysis/prediction. 

## Step 1: Install Nextflow  

To get started, install Nextflow by following the instructions provided in the [Nextflow documentation](https://www.nextflow.io/docs/latest/install.html).  

Steps: 
```
sudo apt install zip unzip

curl -s https://get.sdkman.io | bash

#Open new terminal 

sdk install java 17.0.10-tem

curl -s https://get.nextflow.io | bash

chmod +x nextflow

#export PATH="/home/DIR:$PATH"

mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh

#close and reopen your terminal 
source ~/miniconda3/bin/activate

conda init --all
pip install numpy
```

## Step 2: Running the Nextflow Pipeline

Once you have set up Nextflow and configured the pipeline, you can execute it using the `nextflow` command. Here's an explanation of the key components of the command:

#### General Syntax:
```bash
nextflow run main.nf [OPTIONS]
```

### Options in Detail:

#### **`--sequence`**
This specifies the input sequence file (e.g., a FASTA file). Replace `example/H1140.fasta` with the path to your input sequence file.

#### **`--run`**
Defines a custom tag or identifier for your run. In the example, the value `test` is used to label the execution run.

#### **`--database_dir`**
Specifies the directory containing the database files required for the analysis. Update this to the path of your database directory.

---

### Nextflow-Specific Flags:

#### **`-resume`**
- When you run a workflow with `-resume`, Nextflow will continue the execution from where it left off, reusing cached results for previously completed steps.  
- This is particularly useful if a run was interrupted or if you want to avoid re-running steps with unchanged inputs.

#### **`-profile`**
- Profiles are configurations that define how the pipeline runs in different environments, such as on a local machine, a cluster, or the cloud.  
- Common profiles include:
  - **`docker`**: Runs the pipeline within Docker containers for reproducibility and isolation.
  - **`slurm`**: Configures the pipeline for SLURM-based clusters.
  - **`local`**: Runs the pipeline on the local machine.

To use Docker, ensure Docker is installed and running on your system. Use the `-profile docker` flag to execute the workflow in a Dockerized environment.

---

### Example Command:
```bash
./nextflow run main.nf --sequence example/H1140.fasta --run test --database_dir ~/data/public/colabfold/ -profile docker -resume
```

### Explanation of the Example:
1. **`main.nf`**: This is the main workflow file of your Nextflow pipeline.
2. **`--sequence example/H1140.fasta`**: Specifies the input sequence file.
3. **`--run test`**: Labels the run as "test".
4. **`--database_dir ~/data/public/colabfold/`**: Points to the directory containing necessary database files.
5. **`-profile docker`**: Runs the pipeline inside Docker containers.
6. **`-resume`**: Reuses the cached results of completed steps.
