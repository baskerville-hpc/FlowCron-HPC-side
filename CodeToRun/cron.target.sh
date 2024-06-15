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

      write_log "mv $UoW $work_dir complete. Removing sentinel ${work_dir}/sentinels/${copy_sentinel_files}."
      rm "${work_dir}/sentinels/${copy_sentinel_files}"
      if [[ $? -eq 0 ]]; then
          write_log "Successfully removed sentinel."
      else
          write_log "FATAL ERROR - Unable to delete copy sentinels using rm ${work_dir}/sentinels/${copy_sentinel_files}"
          continue
      fi

      #Increment count of files ran
      count=$((count+1))

      #this means we can never copy to the same directory in slurm/ due to changing the time.
      sleep 1
    fi
done <<< $(findPossibleUnitsOfWorkSentinelCreatedByGlobus "${holding_area}")
write_log "Complete; moved ${count} Units of work to slurm/."

#Reusing findPossibleUnitsOfWork but targeting the slurm/ directory.
count=0

# LOOP 2 - Start the HPC job and setup cleanup.
while read UoW_slurm; do
  if [[ -n "${UoW_slurm}" ]]; then #test for an empty value. This is given if findPossible... looks at an empty dir.
    #Customise slurm file
    submission_script=''

    find_first_script "${UoW_slurm}"/scripts
    path_to_slurm_file=$submission_script
    if [ $? -ne 0 ]; then
      write_log "FAILED when trying to find a valid slurm script; bypassing cleanup and moving ${UoW_slurm} directory"
      mv "${UoW_slurm}" ${failed_area}
      continue
    fi

    write_log "INFO: rewriting output and error slurm directives in ${path_to_slurm_file}"
    correct_error_and_output "${path_to_slurm_file}" "${UoW_slurm}"

    if [ $? -ne 0 ]; then
      write_log "FAILED when rewriting slurm script; bypassing cleanup and moving ${UoW_slurm} directory"
      mv "${UoW_slurm}" ${failed_area}
      continue
    fi

    write_log "Converting the slurm script ${path_to_slurm_file} to UNIX \n format, just in case."
    dos2unix ${path_to_slurm_file}
    find ${UoW_slurm}/scripts -type f -iname '*.sh' -exec dos2unix {} \;

    if [ $? -ne 0 ]; then
      write_log "dos2unix file conversion failed for file ${path_to_slurm_file}"
      continue
    fi
    
    #Create a sentinel to prevent it being analysed multiple times
    write_log "Creating SlurmRunning sentinel ${UoW_slurm}/sentinels/SlurmRunning"
    touch "${UoW_slurm}/sentinels/SlurmRunning"

    if [ $? -ne 0 ]; then
      write_log "FAILED to create a sentinel to prevent work being analysed multipled times"
      mv "${UoW_slurm}" ${failed_area}
      continue
    fi

    #Start analysis
    write_log "${executable_to_run} ${path_to_slurm_file} ${UoW_slurm}"

    job_id=$(${executable_to_run} "${path_to_slurm_file}"  "${UoW_slurm}")

    if [ $? -ne 0 ]; then
      write_log "FAILED when running slurm script; bypassing cleanup and moving ${UoW_slurm} directory"
      mv "${UoW_slurm}" ${failed_area}
      continue
    fi
    
    #Copy to a destination based on existence of a slurm stats file and it containing "Exitcode 0:0"
    write_log "cron.target sent ${executable_to_run} ${path_to_slurm_file} ${UoW_slurm} with JobID ${job_id} to the queue"
    cleanup_job_id=$(sbatch --dependency afterany:${job_id} --parsable ${cleanup_script} ${UoW_slurm} ${job_id})
    
    if [ $? -ne 0 ]; then
      write_log "FAILED when running slurm clean up script, will need to manually clean up. Check that you've set QoS and Account in cleanup.sh"
      continue
    fi
    write_log "clean_up created with ${cleanup_job_id} to the queue"

    #Increment count of files ran
    count=$((count+1))
  fi
done <<< $(findPossibleUnitsOfWork "slurm")

write_log "Complete; analysed ${count} files."

#deleting old log files
write_log "Deleting old files."
delete_old_logs

write_log "Complete; deleted old log files"
