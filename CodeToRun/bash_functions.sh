#General FlowCron functions James Allsopp 2024

#Writes the argument to a log file
function write_log {
   echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t ${1}" >> $logging_file
}

#Deletes log and slurm files placed in /Bin after a given number of days
function delete_old_logs {
    find ${logging_directory} -mtime +${days_after_we_should_delete_log_files} -exec rm -- '{}'  \;
    find ${cleanup_area} -mtime +${days_after_we_should_delete_log_files} -exec rm  -- '{}'  \;
}

#Soft delete, moves files to soft delete areea 
function soft_delete  {
    if [[ SOFTDELETE_DAYS -gt 0 ]]; then
        find ${success_area} -maxdepth=1 -mtime +${SOFTDELETE_DAYS} -exec mv '{}' "${soft_success_area}"  \;
        find ${failed_area} -maxdepth=1 -mtime +${SOFTDELETE_DAYS} -exec mv '{}'  "${soft_failed_area}"\;
    fi 
}

function hard_delete  {
    if [[ HARDDELETE_DAYS -gt 0 ]]; then
        find ${soft_success_area} -maxdepth=1 -mtime +${HARDDELETE_DAYS} -exec rm -r -- '{}'  \;
        find ${soft_failed_area} -maxdepth=1 -mtime +${HARDDELETE_DAYS} -exec rm -r -- '{}'  \;
    fi
}


#Function used to create directories, checking for existence before and after.
function create_dir {
   if [ ! -d "${1}" ];then 
       mkdir -p "${1}"
       if [ $? -ne 0 ]; then
	  write_log "${1} does not exist and we cannot create it"
       fi
   fi
}

#function is used to work out if the directory matches the unit of work format
# example_job
#   |->data
#   |->scripts
#   |->sentinels
function IsDirectoryAUnitOfWork {
  if [ ! -d "${1}/data" ];then
    return 1
  fi
  if [ ! -d "${1}/scripts" ];then
    return 1
  fi
  if [ ! -d "${1}/sentinels" ];then
    return 1
  fi

  return 0
}

#Wait to for the globus flow to delete the sentinel before starting work, don't want to start analysing whilst it's
#being uploaded
function doesUnitOfWorkNOTContainASentinelFile {
  if [ ! -d "${1}/sentinels" ];then
    return 2
  fi

  if [ $(ls -A "${1}/sentinels" | wc -l) -ne 0 ];then
    return 1
  fi
  
  return 0
  
}

# This is a variation of findPossibleUnitsOfWork which accounts for the fact the sentinel directory and file isn't necessarily the first file to be transferred by Globus.
# Hence we don't transfer the sentinel directory, we create it at the end of the run, which simplifies the unit of work.
function findPossibleUnitsOfWorkSentinelCreatedByGlobus {
  write_log "Begin findPossibleUnitsOfWorkCreatedByGlobus"
  #be really careful with the spaces in this command between the sentences.
  mapfile -d '' prospective_directories < <( find "${1}"/ -mindepth 1 -maxdepth 1 -type d -print0)
   
  for i in "${prospective_directories[@]}"; do
    if IsDirectoryAUnitOfWork "${i}"; then
      doesUnitOfWorkNOTContainASentinelFile "${i}"
      if [ $? -eq 0 ]; then
	#Success path, an empty sentinels directory  
        echo "${i}"
      else
        write_log "Unit of Work ${i} contains a sentinel file, probably still being copied to the slurm directory"
      fi
    else
      write_log "Unit of Work ${i} is not a valid unit of work, as the sentinels directory has not been created yet . This will need to be manually created"
    fi
  done

  return 0
}

#[work@hawaiian GlobusFlowsSDKTarget]$ mapfile -d ''  array_test < <( find Testing/ -mindepth 1 -maxdepth 1 -type d -print0)
#[work@hawaiian GlobusFlowsSDKTarget]$ printf '%s\n' "${array_test[@]}"
#Testing/this has spaces in
#Testing/help
function findPossibleUnitsOfWork {
  write_log "Begin findPossibleUnitsOfWork"
  #be really careful with the spaces in this command between the sentences.
  mapfile -d '' prospective_directories < <( find "${1}"/ -mindepth 1 -maxdepth 1 -type d -print0)
 
  for i in "${prospective_directories[@]}"; do
    if IsDirectoryAUnitOfWork "${i}"; then
      doesUnitOfWorkNOTContainASentinelFile "${i}"
      if [ $? -eq 0 ]; then        
          write_log "${i} does not contain a sentinel file"
	  echo "${i}" #This is the return value that makes this function work
      else
        write_log "Unit of Work ${i} still contains a sentinel file"
      fi
    else
      write_log "Unit of Work ${i} is not a valid unit of work, this will need to be manually deleted"
    fi
  done

  return 0
}


#Use this when looking for a single valid slurm file
#1st argument is the directory to search, second the search term
function findOnlyOneFileMatching {
    readarray -d '' file_list < <(find "$1" -name "$2" -print0)

    if [ ${#file_list[@]} -eq 1 ]; then
	write_log "Found a single matching slurm file ${file_list[0]}"
	echo "${file_list[0]}"
	return 0
    fi
    write_log  "Found multiple or no slurm files in $1"
    return 1
}


#This checks that the file is a valid bash script
function check_for_valid_bash_shebang {
  file_to_check=$1
  grep_test=$(head -n1 "${file_to_check}" | grep -i '^\#!/bin/bash')
  if [ ! -z "${grep_test}" ]; then
    return 0
  fi
  return 1
}

#Attempts to detect any or no output or error slurm directives and correct them for use in hte script.
#This allows you to recycle UoW's that have been passed through previously.

function correct_error_and_output {
    file_to_check=$1
    UoW_slurm_local=$2
    write_log "INFO: file to check ${file_to_check} UoW_slurm_local is ${UoW_slurm_local}"
    #Check for short forms and substitute first
    grep_error=$(grep -E '#SBATCH\s+-e[[:blank:]=\"]+' "${file_to_check}")
    grep_error_long_form=$(grep -E '#SBATCH\s+--error[[:blank:]=\"]+' "${file_to_check}")
    if [ ! -z "${grep_error}" ]; then
        # if found, use sed to substitute entire line
        sed -i'' -e 's#\#SBATCH\s-e.*#\#SBATCH --error="'"${UoW_slurm_local}"'/slurm-%j.err"#' "${file_to_check}"
    elif [ ! -z "${grep_error_long_form}" ]; then
        # if found, use sed to substitute entire line
        sed -i'' -e 's#\#SBATCH\s--error.*#\#SBATCH --error="'"${UoW_slurm_local}"'/slurm-%j.err"#' "${file_to_check}"
    else
        #if not found add #SBATCH --error after /bin/bash
        check_for_valid_bash_shebang "${file_to_check}" || return 1
        sed -i '/#!\/bin\/bash/a \#SBATCH --error="'"${UoW_slurm_local}"'\/slurm-%j.err"' "${file_to_check}"
    fi


    grep_output=$(grep -E '#SBATCH\s+-o[[:blank:]=\"]+' "${file_to_check}")
    grep_output_long_form=$(grep -E '#SBATCH\s+--output[[:blank:]=\"]+' "${file_to_check}")
    if [ ! -z "${grep_output}" ]; then
        # if found, use sed to substitute entire line
        sed -i'' -e 's#\#SBATCH\s-o.*#\#SBATCH --output="'"${UoW_slurm_local}"'/slurm-%j.out"#' "${file_to_check}"
    elif [ ! -z "${grep_output_long_form}" ]; then
        # if found, use sed to substitute entire line
        sed -i'' -e 's#\#SBATCH\s--output.*#\#SBATCH --output="'"${UoW_slurm_local}"'/slurm-%j.out"#' "${file_to_check}"
    else
        check_for_valid_bash_shebang "${file_to_check}" || return 1
        #if not found add #SBATCH --error after /bin/bash
        sed -i '/#!\/bin\/bash/a \#SBATCH --output="'"${UoW_slurm_local}"'\/slurm-%j.out"' "${file_to_check}"
    fi

    return 0
}

#Use this function to check for either submission_script.sh or a valid and singular script, as defined by having a shebang and a line '^#SBATCH......'
function find_first_script {
   path_to_search="$1"
   submission_script=""
   write_log "INFO: running find_first_script, looking for a script in $path_to_search"
   if [ ! -d "${path_to_search}" ]; then
     write_log "Error: path ${path_to_search} does not exist"  
     return 1
   fi
   
   if [ -f "${path_to_search}/submission_script.sh" ]; then
       write_log "INFO; found default submission script ${path_to_search}/submission_script.sh so using that."
       submission_script="${path_to_search}/submission_script.sh" 
       return 0
   fi
   scripts=(); for i in "$path_to_search"/*; do temp=$(grep -l -E "^#SBATCH" "${i}"); if [ ! -z "${temp}" ]; then if check_for_valid_bash_shebang "$temp"; then scripts+=("${temp}"); fi; fi; done
   val=${#scripts[@]}
   if [ $val -ne 1 ]; then
     write_log "INFO; found either no or multiple possible submission scripts."
     ${path_to_search}/submission_script.sh
     return 1 
   fi
   
   submission_script="${scripts[0]}"
   write_log "INFO; successfully found a possible submission script. ${submission_script}"
   return 0
 }

# This is a function to generate some test directories to check the other functions. e.g. findPossibleUnitsOfWork
function createTestDirs {
  mkdir -p ${1}/"TestingEmpty"
  mkdir -p ${1}/"Testing EmptywithSpaces"
  
  mkdir -p ${1}/"Testing/TestEmpty"
  mkdir -p ${1}/"Testing/TestScriptsOnly/scripts"
  mkdir -p ${1}/"Testing/TestDataOnly/data"
  mkdir -p ${1}/"Testing/TestSentintelsOnly/sentinels"

  
  mkdir -p ${1}/"Testing/Working/"{scripts,data,sentinels}
  mkdir -p ${1}/"Testing/Working with spaces/"{scripts,data,sentinels}

  mkdir -p ${1}/"Testing/Working with sentinels/"{scripts,data,sentinels}
  touch ${1}/"Testing/Working with sentinels/sentinels/UnfinishedUpload"
}

