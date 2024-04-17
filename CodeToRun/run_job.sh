#!/bin/bash
#SBATCH --account jgms5830-rfi-automat  
#SBATCH --qos rfi                                                 
#SBATCH --time 5:0:0   #Five hours might be too long                    
#SBATCH --job-name GlobusUploadFileAnalysis                             
#SBATCH --error="SUBST-%j.err"                                                                         
#SBATCH --output="SUBST-%j.out"
                                                                        
#NOTE: This file is not meant to be run directly and is just a template for each job and is editted by cron.target.sh

#Edit account and qos to your own values which can be found from the my_baskerville command or admin.baskerville.ac.uk    

source environment_variables.sh

module purge                                                            
hostname=$(hostname)
if [[ "${hostname}" == *"baskerville"* ]] ;then
   module load bask-apps/live/live
   module load Python/3.10.4-GCCcore-11.3.0
elif [[ "${hostname}" == *"bb2"* ]] ;then
   module load bluebear                                            
   module load bear-apps/2021b/live
   module load Python/3.9.6-GCCcore-11.2.0
else
   write_log "Unknown value for ${hostname}"
   exit 1
fi


working_directory=$1
input_file=$2

cd $working_directory || (write_log "Failed to cd to ${working_directory}" && return 1)

python LocateRestrictionSites.py $input_file
#python ../../test.py $input_file

if [ $? -eq 0 ]; then
    write_log "${SLURM_JOB_ID}: File ${1} successfully analysed.."                                                    
    sentinel=""
    if [ -f FAILED-* ]; then # could use shopt -s nullglob
       sentinel=$(ls FAILED-*); 
       number_of_files=$(ls FAILED-* | wc -l);
       if (( $number_of_files == 1)); then
	  mv $sentinel $(echo $sentinel | sed 's/FAILED/SUCCESS/g');
       else
	  write_log "${SLURM_JOB_ID}: More than one sentinel was not expected ${sentinel}.";	      
       fi;
    else
	write_log "${SLURM_JOB_ID}: File ${1} Unable to find sentinel.";
    fi;
else             
    write_log "${SLURM_JOB_ID}: File ${1} unsuccessfully analysed. Retaining sentinel";                                                  
fi                                                                      
           
