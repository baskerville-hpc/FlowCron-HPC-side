#!/bin/bash
#SBATCH --account edmondac-rsg
#SBATCH --qos arc
#SBATCH --time 5:0:0   #Five hours might be too long
#SBATCH --job-name test_job #<give this a name for this system, so it shows up clearly in squeue>
#SBATCH --error="SUBST-%j.err"
#SBATCH --output="SUBST-%j.out"

#Edit account and qos to your own values which can be found from the my_baskerville command or admin.baskerville.ac.uk
#If you edit --error or --output, just make sure they end in either %j.out or %j.err. Otherwise things will break,

#This script needs to path to the root of the "Unit of Work" supplied as a command line option. This is the directory containing 'data' and 'scripts'

module purge

hostname=$(hostname)
if [[ "${hostname}" == "bask"* ]] ;then
   module load bask-apps/live/live
   # Add your Baskerville modules here

elif [[ "${hostname}" == *"bb2"* ]] ;then
   module load bluebear
   # Add your Bluebear modules here
else
   write_log "Unknown value for ${hostname}"
   exit 1
fi

working_directory=$1

echo "${SLURM_JOB_ID}: Working directory is ${working_directory}"

if ! [ -d $working_directory ]; then
  echo "${SLURM_JOB_ID}: ${working_directory} has not been found"
fi

cd "${working_directory}"

#Your code between here--------------------------------
current_script=$(basename "$0")
echo "${current_script} has run"> "data/submission_script.output"

# And here----------------------------------------------------
