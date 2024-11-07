
#!/bin/bash

#This is a script to setup the cronjob automatically - JA 17th April
CRON_HOST="$(hostname)"
CRON_MIN=5
COLOUR_RED='\e[0;31m'
COLOUR_RESET='\033[0m'
CURRENT_DIR="$(pwd)"

TIME_OPTS=("1" "2" "5" "10" "15" "30")

flow_cron_config_dir="${HOME}/.config/flowcron"

which my_baskerville > /dev/null 2>&1 
usingBaskerville=$?

#given a value and an array, is the value in the array, returns 0 if found and 1 if not.
function isValueInArray {
  local value=$1
  shift
  local arr=("$@")
  for test in "${arr[@]}"; do
     if [ ! -z "${value}" ]; then
        if [ "${value}" == "${test}" ]; then
            return 0
	    fi
     fi
  done
  return 1
}

cat << EOF
Welcome to the FlowCron setup script.

This will create a file in your home directory which cron will run every x
minutes, which will call the bash script in ${CURRENT_DIR}/CodeToRun/cron.target.sh

Cron jobs aren't shared between users in Baskerville and will be wiped out in a system upgrade. We will store a backup
for you as part of this script in "${flow_cron_config_dir}"

This script creates an executable in your home directory, which can be accessed from any host. However the cron job only runs on one host, so make a note or look in the config. The cron job can't run FlowCron directly so it has to run the executable first due to way cron is setup. 

When you're asked for a name, please make this unique to your instances of FlowCron.
 
EOF

if [ ! -d ${flow_cron_config_dir} ]; then
    mkdir -p "${flow_cron_config_dir}"
fi

CRON_SCRIPT_NAME=""

#Get a name for the script from the user.
while true ; do
    echo  -ne "What name would you like to give to this instance of Flowcron?\n> "
    read  CRON_SCRIPT_NAME
    if [ ! -z $CRON_SCRIPT_NAME ]; then
	CRON_SCRIPT_NAME=${CRON_SCRIPT_NAME%.sh}".sh"
	break
    else
	echo "Please enter a value for the name of the script."	    
    fi
done

#Get an account name from the user. This is so we can drop these into the cleanup file. Otherwise, they try toget this to work
while true ; do
    echo -ne "What Slurm QoS would you like this to run under? You can list your available QoS using the command 'my_baskerville'. If you're not using Baskerville, just add the appropriate QoS value given by your system admins.\n?"
    read CRON_QOS_NAME
    if [ ! -z $CRON_QOS_NAME ]; then
        if [ $usingBaskerville -eq 0 ]; then
            CHECK=$(my_baskerville | grep "QoS.*:")
            CHECK=${CHECK##*:}
            CHECK_ARRAY=($(echo $CHECK | sed 's/\s*,\s*/ /g'))
  	        isValueInArray  $CRON_QOS_NAME "${CHECK_ARRAY[@]}"
            if [ $? -eq 0 ]; then
              break
            fi
        else
            break
        fi
    fi
	echo "Please enter a QoS for the script."	    
done


#Get an account name from the user.
while true ; do
    echo "What Slurm account would you like this to run under? You can list your accounts using the command 'my_baskerville'.  If you're not using Baskerville, just add the appropriate QoS value given by your system admins.\n?"
    read CRON_ACCOUNT_NAME
    if [ ! -z $CRON_ACCOUNT_NAME ]; then
        if [ $usingBaskerville -eq 0 ]; then
            CHECK=$(my_baskerville | grep "$CRON_QOS_NAME.*:")
            CHECK=${CHECK##*:}
            CHECK_ARRAY=($(echo $CHECK | sed 's/\s*,\s*/ /g'))
            isValueInArray  $CRON_ACCOUNT_NAME "${CHECK_ARRAY[@]}"
            if [ $? -eq 0 ]; then
              break
            fi
        else
          break
        fi
    fi
	echo "Please enter an account name for the script."	    
done

#Ask how many minutes should this repeat
echo -e "\nEvery how many minutes should this Cron job run? Use the row number to select."
select time in "${TIME_OPTS[@]}"
do
    for i in "${TIME_OPTS[@]}"; do
	if [ "${time}" == "${i}" ]; then
            CRON_MIN=$time; break 2;
	fi
    done
done

if [ -e ~/$CRON_SCRIPT_NAME ];
then
    OVERWRITE="This file will be overwritten"
fi

yes_no=("Yes" "No")
echo "Would you like to add a timestamp to each uploaded Unit of Work to prevent clobbering? If no, we recommend you do that manually."
select yn in  "${yes_no[@]}"
do
    case $yn in
	"Yes")
	    ADD_TIMESTAMP="True"
	    break
	    ;;
	"No")
	    break
	    ;;
	*)
	    echo "Unknown option"
	    ;;
     esac
done

echo "Would you like to use SCRON instead of CRON? If SCRON is avaiable, we would recommend it."
select yn in  "${yes_no[@]}"
do
    case $yn in
	"Yes")
	    USE_SCRON="True"
	    break
	    ;;
	"No")
	    break
	    ;;
	*)
	    echo "Unknown option"
	    ;;
     esac
done

#How many days before a job is soft-deleted
while true ; do
    echo -ne "How many days should pass before we soft-delete completed or failed jobs; 0 indicates no soft-deletion?\n>"
    read  SOFTDELETE_DAYS
    if [[ $SOFTDELETE_DAYS =~ ^[\-0-9]+$ ]] && (( SOFTDELETE_DAYS > -1)); then
	break
    else
	echo "Please enter an integer number of days for soft deletion."	    
    fi
done

#How many days before a job is finally deleted
while true ; do
    echo -ne "How many days should pass (after copying to soft delete) before we finally delete completed or failed jobs; 0 indicates no final deletion?\n>"
    read  HARDDELETE_DAYS
    if [[ $HARDDELETE_DAYS =~ ^[\-0-9]+$ ]] && (( HARDDELETE_DAYS > -1)); then
	break
    else
	echo "Please enter an integer number of days for final deletion."	    
    fi
done

set -o noglob # Need this to prevent the asterisks in the cron job sending everything haywire.
CRON_COMMAND="*/${CRON_MIN} * * * * ./${CRON_SCRIPT_NAME}"

$([[ -v USE_SCRON ]] && echo "Yes" || echo "No")


warning=$(cat <<EOF
We will set up with these options;
Name of script:                      $CRON_SCRIPT_NAME   ${COLOUR_RED}${OVERWRITE}${COLOUR_RESET}
QoS:                                 $CRON_QOS_NAME
Account:                             $CRON_ACCOUNT_NAME
Repeat Time:                         $CRON_MIN minutes
Host for cron file:                  $CRON_HOST
Add Timestamp to uploaded Directory: $NICE_ADDTIMESTAMP
Time before Soft deletion (days):    $SOFTDELETE_DAYS  
Time before Hard deletion (days):    $HARDDELETE_DAYS  
Use SCRON rather than CRON:          $NICE_SCRON
Y
EOF
)
echo "$warning"

echo "Confirm to continue?"
select yn in  "${yes_no[@]}"
do
    case $yn in
	"Yes")
	    echo -e "\nContinuing...."
	    break
	    ;;
	"No")
            echo -e "\nExiting script on user request"
	    exit
	    ;;
	*)
	    echo "Unknown option"
	    ;;
     esac
done

echo -e "${warning}" > "${flow_cron_config_dir}/$(date +%FT%T)_${CRON_SCRIPT_NAME}"

echo "${new_cron}" | crontab -
set +o noglob

#create file in home directory to execute, can't directly do this due to permissions in CRON.

cat <<EOF > ~/${CRON_SCRIPT_NAME}
#!/bin/sh
#Created by FlowCron setup on $(date); git version $(git rev-parse --short HEAD)

"${CURRENT_DIR}/CodeToRun/cron.target.sh" "${CURRENT_DIR}/CodeToRun"

EOF

chmod +x ~/${CRON_SCRIPT_NAME}

path_to_environment_variables="./CodeToRun/environment_variables.sh"

if [[ -v USE_SCRON ]]; then
    CRON_EXECUTABLE="scrontab"
else
    CRON_EXECUTABLE="crontab"
fi

#This attempts to not clobber existing scron, whilst being functional idempto....
original_cron=$(${CRON_EXECUTABLE} -l)
new_cron=$(echo "${original_cron}" | sed 's/'^.*${CRON_SCRIPT_NAME}.*$'//g')

if [[ -v USE_SCRON ]]; then
    new_cron=$(cat << EOF
${new_cron}

#DIR=${HOME}
#SCRON --qos=${CRON_QOS_NAME}
#SCRON --output=/dev/null
#SCRON --error=/dev/null
#SCRON --account=${CRON_ACCOUNT_NAME}
#SCRON -t 00:01:00

# Added by Flowcron on $(date) for script ${CRON_SCRIPT_NAME}; do not delete without deleting line below
${CRON_COMMAND}
EOF
    )
else
    new_cron=$(cat << EOF
${new_cron}

# Added by Flowcron on $(date) for script ${CRON_SCRIPT_NAME}; do not delete without deleting line below
${CRON_COMMAND}
EOF
    )
fi

NICE_ADDTIMESTAMP=$([[ -v ADD_TIMESTAMP ]] && echo "Yes" || echo "No")
NICE_SCRON=$([[ -v USE_SCRON ]] && echo "Yes" || echo "No")


warning=$(cat <<EOF
We will set up with these options;
Name of script:                      $CRON_SCRIPT_NAME   ${COLOUR_RED}${OVERWRITE}${COLOUR_RESET}
QoS:                                 $CRON_QOS_NAME
Account:                             $CRON_ACCOUNT_NAME
Repeat Time:                         $CRON_MIN minutes
Host for cron file:                  $CRON_HOST
Add Timestamp to uploaded Directory: $NICE_ADDTIMESTAMP
Time before Soft deletion (days):    $SOFTDELETE_DAYS  
Time before Hard deletion (days):    $HARDDELETE_DAYS  
Use SCRON rather than CRON:          $NICE_SCRON
Y
EOF
)
echo "$warning"

echo "Confirm to continue?"
select yn in  "${yes_no[@]}"
do
    case $yn in
	"Yes")
	    echo -e "\nContinuing...."
	    break
	    ;;
	"No")
            echo -e "\nExiting script on user request"
	    exit
	    ;;
	*)
	    echo "Unknown option"
	    ;;
     esac
done

echo -e "${warning}" > "${flow_cron_config_dir}/$(date +%FT%T)_${CRON_SCRIPT_NAME}"

echo "${new_cron}" | ${CRON_EXECUTABLE} -
set +o noglob

#create file in home directory to execute, can't directly do this due to permissions in CRON.

cat <<EOF > ~/${CRON_SCRIPT_NAME}
#!/bin/sh
#Created by FlowCron setup on $(date); git version $(git rev-parse --short HEAD)

"${CURRENT_DIR}/CodeToRun/cron.target.sh" "${CURRENT_DIR}/CodeToRun"

EOF

chmod +x ~/${CRON_SCRIPT_NAME}

path_to_environment_variables="./CodeToRun/environment_variables.sh"

#Add Timestamp option to environment variables
if [[ -v ADD_TIMESTAMP ]]; then
    grep_test=$(grep "ADD_TIMESTAMP" "${path_to_environment_variables}")
    if [ -z "${grep_test}" ]; then
        echo -e "#ADD_TIMESTEP Added automatically by setup.sh\nADD_TIMESTAMP=1" >> "${path_to_environment_variables}"
    else
	#Wipe old values and replace.
	sed -i'' -E 's/^ADD_TIMESTAMP.*$//g' "${path_to_environment_variables}"
        sed -i'' -E 's/^\#ADD_TIMESTAMP Added automatically by setup.sh.*$//g' "${path_to_environment_variables}"
	echo -e "#ADD_TIMESTEP Added automatically by setup.sh\nADD_TIMESTAMP=1" >> "${path_to_environment_variables}"
    fi
else	    
    sed -i'' -E 's/^ADD_TIMESTAMP.*$//g' "${path_to_environment_variables}"
    sed -i'' -E 's/^\#ADD_TIMESTAMP Added automatically by setup.sh.*$//g' "${path_to_environment_variables}"
fi

#Substitute the users chosen QoS and Account into the cleanup.sh
sed -i "s/#SBATCH --account.*/#SBATCH --account ${CRON_ACCOUNT_NAME}/g" ${CURRENT_DIR}/CodeToRun/cleanup.sh
sed -i "s/#SBATCH --qos.*/#SBATCH --qos ${CRON_QOS_NAME}/g" ${CURRENT_DIR}/CodeToRun/cleanup.sh

#Both SOFT AND HARD DELETE SHOULD ALWAYS BE DEFINED
#Add SOFTDELETE to environment variables files
grep_test=$(grep "SOFTDELETE_DAYS" "${path_to_environment_variables}")
if [ -z "${grep_test}" ]; then
    #Not found this value in the Environment variables file
    echo -e "#SOFTDELETE_DAYS Added automatically by setup.sh\nSOFTDELETE_DAYS=$SOFTDELETE_DAYS" >> "${path_to_environment_variables}"
else
    #wipe the old values and reapply if setup.sh is rerun.
    sed -i'' -E 's/^SOFTDELETE_DAYS=.*$//g' "${path_to_environment_variables}"
    sed -i'' -E 's/^\#SOFTDELETE_DAYS Added automatically by setup.sh.*$//g' "${path_to_environment_variables}"
    echo -e "#SOFTDELETE_DAYS Added automatically by setup.sh\nSOFTDELETE_DAYS=$SOFTDELETE_DAYS" >> "${path_to_environment_variables}"
fi

#Add HARDDELETE to environment variables files
grep_test=$(grep "HARDDELETE_DAYS" "${path_to_environment_variables}")
if [ -z "${grep_test}" ]; then
    #Not found this value in the Environment variables file
    echo -e "#HARDDELETE_DAYS Added automatically by setup.sh\nHARDDELETE_DAYS=$HARDDELETE_DAYS" >> "${path_to_environment_variables}"
else
    #wipe the old values and reapply if setup.sh is rerun.
    sed -i'' -E 's/^HARDDELETE_DAYS=.*$//g' "${path_to_environment_variables}"
    sed -i'' -E 's/^\#HARDDELETE_DAYS Added automatically by setup.sh.*$//g' "${path_to_environment_variables}"
    echo -e "#HARDDELETE_DAYS Added automatically by setup.sh\nHARDDELETE_DAYS=$HARDDELETE_DAYS" >> "${path_to_environment_variables}"
fi

echo "COMPLETE!"
