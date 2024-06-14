# FlowCron - Server-Side

This code is designed to receive a set of files, in a given arrangement, and analyse them on a HPC system, before making them available for download. It is designed to work with either Globus Flows or rsync.

## Scheduling this to run

First,clone this reposiory either Baskerville or BlueBear in your project directory, then run the setup. The only requirement for other HPC systems is to have slurm and cron available. You're chosen config will be stored in ~/.config/flowcron, which can be changed in the setup.sh if you have more than one FlowCron instance. In setup.sh, you'll be asked to name the cron job, how often the cron job should run, and whether to add a timestamp to uploaded Units of Work to prevent similarly named Units of Work merging.

On a HPC system where there are multiple login nodes the cron file will be installed to the login node the setup script is run from.

Each time this runs it will create, if necessary, five new directories alongside CodeToRun called;

+ AnalysedFiles - Where successfully analysed files are placed
+ Bin - where cleanup slurm files are placed. This should be periodically emptied
+ FailedJobs - Where jobs that did not successfully complete are placed
+ Logs - Where Output from the scripts is put.
+ UploadedFiles - Where files to be analysed should be put

Remember to change the Account and QoS in cleanup.sh

Should you require it, these can be changed in environment_variables.sh. UploadedFiles is where your flow, or other method, should deposit uploaded files. The format of the upload is called a Unit of Work and has the form;

<name of Unit of Work
|----> data (contains all of the data for the project)
|----> scripts (contains **one** slurm file. Our code will search for a single bash file containing a bash shebang and #SBATCH directive. Finding less or more than this will result in an error. Remember to set the account and QoS values correctly
|----> sentinels, manually created by the user once transfer is complete. Must be empty.

Once the Unit of Work is uploaded, the user must add a directory called **sentinels** to the Unit of Work to signal a complete transfer. Every time cron_target.sh is run, it will then go through the UploadedFiles directory, and if the sentinels condition is met, transfer each Unit of Work to it's own temporary directory, in **CodetoRun/slurm** where the found slurm script from the scripts directory will be run. The sentinels directory is then used to guarantee completion when moving Units of Work between the UploadedFiles, CodeToRun/slurm and either FailedJobs or AnalysedFiles directories and whilst running the slurm job. Clean up after completion of the slurm job is handled by a slurm dependency job defined in cleanup.sh. Moving the Unit of Work to either AnalysedFiles or Failedjobs is determined by the existence of "ExitCode 0:0" in a file whose name is of the form *<job_id>.stats. 

## Testing

Edit **example_unit_of_work/scripts/edit_this_slurm_script.sh** to contain the correct QoS and account, then copy **example_unit_of_work** to UploadedFiles after deployment and run **mkdir UploadedFiles/example_unit_of_work/sentinels**. This should then appear in **AnalysedFiles**. You can check the **Logs** and **Bin** directories to check that everything went to plan.

## Logging

Finally, a directory **Logs** contains a daily log of everything that's happened, containing the job_id of the slurm job.  A Bin directory stores the output from the cleanup script. You could use Globus to periodically move this to a local drive or build a Grafana solution based on this.

## TODO

+ Move logs to an S3 bucket for grafana.
+ Have setup.sh store a QoS and account, and substitute them into cleanup.sh and uploaded slurm files. 
