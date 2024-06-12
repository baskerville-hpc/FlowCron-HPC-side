# Server-side end

## Scheduling this to run

First, move CodeToRun directory to a place on either Baskerville or BlueBear in your project directory. Set up a cronjob using **crontab -e** to run the file **cron_target.sh**. Help setting up a cronjob can be found [here](https://www.digitalocean.com/community/tutorials/how-to-use-cron-to-automate-tasks-ubuntu-1804). You will need to add one line, which will look like this

* * * * * <path to cron_target.sh>/cron_target.sh
or
*/5 * * * * <path to cron_target.sh>/cron_target.sh
for every five minutes

On Baskerville you might find you need to create an executable file in your home directory which is called from your home drectory, which you then use to call cron_target.sh. This is due the restricted PATH a cron may have access to.

Each time this runs it will create, if necessary, five new directories alongside CodeToRun called;

+ AnalysedFiles - Where successfully analysed files are placed
+ Bin - where cleanup slurm files are placed. This should be periodically emptied
+ FailedJobs - Where jobs that did not successfully complete are placed
+ Logs - Where Output from the scripts is put.
+ UploadedFiles - Where files to be analysed should be put

UploadedFiles is where your flow should deposit uploaded files, so you'll need to specify this in the toml file used by run_flow.py.

cron_target.sh will then go through the UploadedFiles directory, and transfer each file to it's own temporary directory, should that file's status change be less than x minutes old. x is controlled by the **time_since_last_run** variable set in the environment_variables.sh file.

## Editing run_job.sh and cleanup.sh

It's important to note that the run_job.sh file is never run directly, a copy is created in a temporary directory, with correct values for the path of the error, output and stats files, and this is what is run. A directory inside CodeToRun is created of the form **slurm/<input_file_name>-<datetime>/** so that the results of each job are transferred with the analysis and you can see exactly what command was run.

However, you will need to edit run_job.sh to include your own values. Most of this will be familiar to slurm users, but here's a checklist
+ Change the account to your account (line 2) 
+ Change the qos to your qos (line 3)
+ Change the job-name (line 5)
+ Change the modules, there's a section for BlueBear (Internal UoB HPC system, lines 18 & 19) and one for Baskerville (Lines 21-23)
+ Change the command to run on Line 35.

The first two steps will have to be applied to cleanup.sh too.

It may be preferable to move all you commands out to a separate file run from run_job.sh, but you'll need to add a line in cron_target.sh, after line 30, copying your new into ${work_dir}, or take the path differences into account.

## Post-job completion

Each input files's temporary directory is then either placed in AnalysedFiles, if successful, or in FailedJobs, if not successful. The slurm job that does this, *cleanup.sh* runs after the first slurm job has returned, regardless of the outcome of the main slurm file. We use a SUCCESS or FAILED sentinel file (with no contents), and assume that the job has failed unless we're confident of success of both the code and the slurm job.

As an example, the slurm_script.sh loads the modules needed for Python and runs a file called **LocateRestrictionSites.sh**

##Logging

Finally, a directory **Logs** contains a daily log of everything that's happened, containing the job_id of the slurm job. This will also need to be periodically pruned. You could use Globus to periodically move this to a local drive.

## Testing

These file are for testing your system and can be safely removed, once you're satisfied everything works.

+ test.py success.txt and fail.txt
+ LocateRestrictionSites.py

For the first test:
+ Comment line 35 and uncomment line 36 of run_job.sh (python ../../test.py $input_file)
+ Run cron.target.sh manually to create all of the directory structure.
+ Copy success.txt and fail.txt into the UploadedFiles directory.
+ Setup a cron job as described in the first part of the this document, or just run cron.target.sh again.

If successful, a success.txt-<datetime> directory should appear in AnalysedFiles and a fail.txt-<datetime> directory if not. The python script test.py just looks for the existence of the word fail on the first line and fails if found.

## TODO

+ Move logs to an S3 bucket for grafana.
+ Make LocationRestrictionSites receive fasta files and output to a file for download.
+ Include a hook in clean_up to run a flow to return the products.
