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
```