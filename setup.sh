#!/bin/bash

CRON_HOST="$(hostname)"
CRON_MIN=5
COLOUR_RED='\e[0;31m'
COLOUR_RESET='\033[0m'
CURRENT_DIR="$(pwd)"

TIME_OPTS=("1" "2" "5" "10" "15" "30")

flow_cron_config_dir="~/.config/flowcron"
#This is a script to setup the cronjob automatically - JA 17th April


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
    read -p "What name would you like to give to this instance of Flowcron?" CRON_SCRIPT_NAME
    if [ ! -z $CRON_SCRIPT_NAME ]; then
	CRON_SCRIPT_NAME=${CRON_SCRIPT_NAME%.sh}".sh"
	break
    else
	echo "Please enter a value for the name of the script."	    
    fi
done

#Ask how many minutes should this repeat
echo -e "\nEvery how many minutes should this Cron job run?"
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
set -o noglob # Need this to prevent the asterisks in the cron job sending everything haywire.
CRON_COMMAND="*/${CRON_MIN} * * * * ./${CRON_SCRIPT_NAME}"

original_cron=$(crontab -l)
new_cron=$(echo "${original_cron}" | sed 's/'^.*${CRON_SCRIPT_NAME}.*$'//g')
new_cron=$(cat << EOF
${new_cron}

# Added by Flowcron on $(date) for script ${CRON_SCRIPT_NAME}; do not delete without deleting line below
${CRON_COMMAND}
EOF
)


warning=$(cat <<EOF
We will set up with these options;
Name of script:                      $CRON_SCRIPT_NAME   ${COLOUR_RED}${OVERWRITE}${COLOUR_RESET}
Repeat Time:                         $CRON_MIN minutes
Host for cron file:                  $CRON_HOST
Add Timestamp to uploaded Directory: $ADD_TIMESTAMP

Your existing crontab will be changed from:
${original_cron}

to: 

${new_cron}
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
#Add Timestamp option to environment variables
if [[ -v ADD_TIMESTAMP ]]; then
    grep_test=$(grep "ADD_TIMESTAMP" "${path_to_environment_variables}")
    if [ -z "${grep_test}" ]; then
        echo -e "#Added automatically by setup.sh\nADD_TIMESTAMP=1" >> "${path_to_environment_variables}"
    fi
else
    sed -i'' -E 's/^ADD_TIMESTAMP.*$//g' "${path_to_environment_variables}"
    sed -i'' -E 's/^\#Added automatically by setup.sh.*$//g' "${path_to_environment_variables}"
fi

echo "COMPLETE!"



