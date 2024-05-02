#!/bin/bash
#SBATCH --account jgms5830-rfi-automat
#SBATCH --qos rfi                                                 
#SBATCH --time 0:5:0   #Five hours might be too long
#SBATCH --job-name GlobusUploadFileAnalysis-cleanup
#SBATCH --output="../Bin/cleanup%j.out"

#NOTE: This file is not meant to be run directly and is just a template for each job and is editted by cron.target.sh

#Edit account and qos to your own values which can be found from the my_baskerville command or admin.baskerville.ac.uk                                              
module purge
source environment_variables.sh

source_dir="$1"
previous_job="$2"

write_log  "${SLURM_JOB_ID}: INFO  Begining clean up with ${source_dir} and ${previous_job}."
if [ -d "${source_dir}" ]; then
  exitcode_check="Exitcode 0:0" #Use this to grep the search file.
    
  project_name=${source_dir##*/}

  destination="${failed_area}"
  
  #Create a copy file sentinel

  cf_sentinel_file="${project_name}/sentinels/COPY-FOR-GLOBUS-DOWNLOAD-${previous_job}"
  slurm_sentinel_file="${project_name}/sentinels/SlurmRunning-${previous_job}"
  touch "slurm/${cf_sentinel_file}"

  #file to search for with success state.
  slurm_stats_file="${previous_job}.stats"

  #So can we find a stats file in the previous job.
 
  found_files=$(findOnlyOneFileMatching "${source_dir}" "*${slurm_stats_file}")
  if [ -z "$found_files" ]; then
      write_log  "${SLURM_JOB_ID}: Could find a slurm stats file, taking to be a fail."
  else
       write_log  "${SLURM_JOB_ID}: search for value ${exitcode_check} in file ${found_files}."
      if grep "${exitcode_check}" "$found_files"; then
	write_log  "${SLURM_JOB_ID}:  found exit code, moving to success area."
	destination="${success_area}"
      else
	write_log  "${SLURM_JOB_ID}:  did not find exit code."
      fi
  fi


  
  write_log  "${SLURM_JOB_ID}: Starting Cleanup in Directory ${source_dir} ${project_name}."
  write_log  "${SLURM_JOB_ID}: Part of ${previous_job}; moving ${source_dir} to ${destination}."
  mv $source_dir $destination
  write_log "${SLURM_JOB_ID}: Copy complete, removing Copy Sentinel ${destination}/${sentinels}"
  rm ${destination}/${cf_sentinel_file}
  write_log  "${SLURM_JOB_ID}: Copy Sentinel removed"

  #fixing permissions
  write_log "${SLURM_JOB_ID}: Fixing permissions for ${destination}."
  find "${destination}" \( -type f -exec chmod g+rw {} \; \) ,  \( -type d -exec chmod g+rwxs {} \;  \)

  #fixing symbolic links by deleting them all; relative ones would be OK, but broken ones cause Globus to fail
  write_log "${SLURM_JOB_ID}: Deleting symbolic links at ${destination}."
  find "${destination}" -type l -delete
  
  #Only remove this after the copy has completed so there's no window for it to be sent for analysis
  write_log "${SLURM_JOB_ID}: Removing sentinels and sentinels directory ${destination}."
  rm ${destination}/${slurm_sentinel_file}

  #remove sentinels directory so that Globus knows to download
  rm -r "${destination}/${project_name}/sentinels"

  write_log  "${SLURM_JOB_ID}: Slurm Sentinel removed"
else
  write_log  "Error: ${SLURM_JOB_ID}: Unable to find source directory ${source_dir}"
fi
           
