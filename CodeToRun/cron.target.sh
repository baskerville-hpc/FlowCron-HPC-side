#!/bin/bash

#This is a command run by a crontab that wraps the actual functions you want to run. If you want to understand what's going on, start here. look to the bottom of the loops for the command that's controlling the interation. There's three stages.
# I. Move from UploadedFiles to CodeToRun/Slurm (first loop)
# II. Start the job (second )
# III. Call the clean up slurm job.
# IV. Delete old logs

# James Allsopp 2024


# Command line argument needed for cron jobs where the job will be started in the home directory, so gives us an option to move to a new directory.

if [[ $# -gt 0 ]]
  then cd "${1}"
fi

source environment_variables.sh

executable_to_run="sbatch --parsable "
run_script="run_job.sh"
cleanup_script="cleanup.sh"
slurm_directory="./slurm"
count=0

write_log "Starting cron.target.sh in directory $(pwd)"

#Look to the bottom of the loop for defn of UoW
#Expecting copy operations for RELION to take longer than the period of the cron job, so adding a sentinel whilst copying to the slurm directory for analysis.

# LOOP 1 -> Move Unit Of Work from UploadedFiles to CodeToRun/slurm/
write_log "Search for directories to analyse"
while read UoW; do
    if [[ -n "${UoW}" ]]; then #test for an empty value. This is given if findPossible... looks at an empty dir.
      #define variables
      short_filename=${UoW##*/}
      
      timestamp=$(date '+%Y%m%d-%H%M%S')

      #RFI's Globus script will add the timestamp to the directory so they know what it's called.
      #Other users might not so we add this to prevent clobbering.
      if [[ -v ADD_TIMESTAMP ]]; then
          work_dir="${slurm_directory}/${short_filename}-${timestamp}"
      else
          work_dir="${slurm_directory}/${short_filename}"
      fi

      #Create workdir; skip to next if this fails.

      if [ -d ${slurm_directory} ]; then
	  write_log "${slurm_directory} exists."
      else
          write_log "Creating directory ${slurm_directory}"
          mkdir ${slurm_directory} || (write_log "Failed to create dir slurm" && continue)
      fi
      
      #Move UoW to the workdir
      write_log "Running mv ${UoW} ${work_dir}"

      #A sentinel file should stop findPossibleUnitsOfWork picking it up again and trying to move it, if it's not finished by the
      #time of the next cron run
      copy_sentinel_files="transfer_to_slurm-${timestamp}"
      write_log "Writing sentinel ${UoW}/sentinels/${copy_sentinel_files} to prevent multiple copies"
      touch "${UoW}/sentinels/${copy_sentinel_files}"
      mv "$UoW" "$work_dir"
      if [[ $? -eq 0 ]]; then
	  write_log "mv $UoW $work_dir complete. Removing sentinel ${work_dir}/sentinels/${copy_sentinel_files}."
      else
          write_log "FATAL ERROR - Move failed for mv ${UoW} ${work_dir}"
          continue
      fi

