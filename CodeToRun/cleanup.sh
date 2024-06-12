#!/bin/bash
#SBATCH --account <put your account here>
#SBATCH --qos <put your QoS here>                                                 
#SBATCH --time 0:10:0
#SBATCH --job-name GlobusUploadFileAnalysis-cleanup
#SBATCH --output="../Bin/cleanup%j.out"

#NOTE: This file is not meant to be run directly
#Edit account and qos to your own values which can be found from the my_baskerville command or admin.baskerville.ac.uk                                              
module purge
source environment_variables.sh

source_dir="$1"
previous_job="$2"

write_log  "${SLURM_JOB_ID}: INFO  Begining clean up with ${source_dir} and ${previous_job}."
pwd
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

  if [[ $? -eq 0 ]]; then
     write_log "${SLURM_JOB_ID}: Move complete, removing Copy Sentinel ${destination}/${cf_sentinel_file}"
  else
      write_log "${SLURM_JOB_ID}: FATAL ERROR - Move failed for ${destination}/${project_name}"
      exit 1
  fi 

  rm ${destination}/${cf_sentinel_file}
  if [[ $? -eq 0 ]]; then
     write_log  "${SLURM_JOB_ID}: Copy Sentinel removed"
  else
      write_log "${SLURM_JOB_ID}: FATAL ERROR - Copy Sentinel not removed ${destination}/${cf_sentinel_file}"
      exit 1
  fi 

  #fixing permissions
  write_log "${SLURM_JOB_ID}: Fixing permissions for ${destination}/${project_name} ."
  target=${destination}/${project_name}
  find "${target}" \( -type f -exec chmod g+rw {} \; \) ,  \( -type d -exec chmod g+rwxs {} \;  \)
  if [[ $? -eq 0 ]]; then
     write_log  "${SLURM_JOB_ID}: Permissions Fixed for ${target}"
  else
     write_log "${SLURM_JOB_ID}: FATAL ERROR - Permissions not fixed for directory ${target}; continuing, but transfer may fail."
  fi 

  #fixing symbolic links by deleting them all; relative ones would be OK, but broken ones cause Globus to fail
  write_log "${SLURM_JOB_ID}: Deleting symbolic links at ${destination}."
  find "${target}" -type l -delete
  if [[ $? -eq 0 ]]; then 
     write_log  "${SLURM_JOB_ID}: Symbolic links deleted for ${target}"
  else
     write_log "${SLURM_JOB_ID}: FATAL ERROR - Symbolic links not fixed for directory ${target}; continuing, but globus transfer may fail."
  fi 
  
  #Only remove this after the copy has completed so there's no window for it to be sent for analysis
  # Do it in two steps in case we want to re-use the sentinels directory   
  write_log "${SLURM_JOB_ID}: Removing sentinels and sentinels directory ${destination}."
  rm ${destination}/${slurm_sentinel_file}
  if [[ $? -eq 0 ]]; then
     write_log  "${SLURM_JOB_ID}: Deleted sentinel file  ${destination}/${slurm_sentinel_file}"
  else
     write_log "${SLURM_JOB_ID}: FATAL ERROR - Unable to delete sentinel file"
  fi 
  
  #remove sentinels directory so that Globus knows to download
  rm -r "${destination}/${project_name}/sentinels"
  if [[ $? -eq 0 ]]; then 
     write_log  "${SLURM_JOB_ID}: Deleted sentinels directory ${destination}/${project_name}/sentinels"
  else
     write_log "${SLURM_JOB_ID}: FATAL ERROR - Unable to delete sentinels directory ${destination}/${project_name}/sentinels"
  fi 
  write_log  "${SLURM_JOB_ID}: Slurm Sentinel removed - Clean up complete."

else
  write_log  "Error: ${SLURM_JOB_ID}: Unable to find source directory ${source_dir}"
fi
           
