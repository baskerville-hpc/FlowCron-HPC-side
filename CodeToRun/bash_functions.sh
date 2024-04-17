#Moved these files to a separate file to test


#Writes the argument to a log file
function write_log {
   echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t ${1}" >> $logging_file
}


#written but not called.
function delete_old_logs {
   find ${logging_directory} -mtime +7 -execdir rm -rf-- '{}' \;
}

#Function used to create directories, checking for existence before and after.
function create_dir {
   if [ ! -d "${1}" ];then 
       mkdir "${1}"
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
      write_log "Unit of Work ${i} is not a valid unit of work, as the sentinel directory has not been created yet . This will need to be manually deleted"
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
        echo "${i}"
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
	echo ${file_list[0]}
	return 0
    fi
    echo ""
    return 1
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

