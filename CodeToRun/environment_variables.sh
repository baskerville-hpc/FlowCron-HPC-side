#Sets up environment variables; James Allsopp 2024
source "bash_functions.sh"

#Variables to be filled in by setup script
qos=""
account=""
time_since_last_run=5
default_job_time="1:00:00"
default_job_name=""
days_after_we_should_delete_log_files=7
logging_directory="../Logs"

if [ ! -d ${logging_directory} ];then 
    mkdir ${logging_directory}
    if [ $? -ne 0 ]; then
       touch "ERROR_in_cron_target-no_logging"
    fi
fi

logging_file="${logging_directory}/$(date '+%Y-%m-%d')_cron_target.log"

holding_area="../UploadedFiles"
failed_area="../FailedJobs"
success_area="../AnalysedFiles"
cleanup_area="../Bin"
soft_failed_area="../SoftDelete/FailedJobs"
soft_success_area="../SoftDelete/AnalysedFiles"

create_dir ${holding_area}
create_dir ${failed_area}
create_dir ${success_area}
create_dir ${cleanup_area}
create_dir ${soft_failed_area}
create_dir ${soft_success_area}
