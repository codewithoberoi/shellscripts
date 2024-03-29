#!/bin/bash

#Version=2

## Config: input_files/s3/s3.cfg
## Fetch AWS Logs on staging IP. Check orders/refids/recharge_number in logs. Write output to a file. Remove logs from staging

TDATE=`date "+%d-%m-%Y-%N"`

usage()
{
	echo "Allow script to perform FETCH AND/OR SEARCH AND/OR REMOVE by configuring respective flag in config as 'true'"
	echo "Config path: input_files/s3/s3.cfg"
}

errors()
{
echo "-----------------------------------------Errors description--------------------------------"
echo "CONFIG_MISS -- Config file used by script doesn't exist on path"
echo "INVALID_BUCKET -- Bucket entered by user doesn't exist in system."
echo "LOGS_FETCH -- Error occured while fetching logs from S3 bucket from staging server(REMOTE_HOST)."
echo "SEARCH_ERROR -- Error occured while trying to grep mentioned pattern by user."
echo "LOGS_REMOVE -- Error occured while trying to remove logs from staging server OR there were no logs present to be removed."
echo "TIMEOUT -- After logs are fetched, when no pattern entered by user to fetch from logs. Script will wait for 20 seconds for user input."
}

bucket_size_check()
{
BUCKET_SIZE=$(ssh -q -l ${USER_NAME} ${REMOTE_HOST} "aws s3 ls --summarize --human-readable --recursive s3://digital-onuslogsarchive-180/${BUCKET}/${DATE}/${HOST}/ | grep \"Total Size\" | grep G | awk '{print \$3}' | cut -d \".\" -f1")
AVAILABLE_SPACE=$(ssh -q -l ${USER_NAME} ${REMOTE_HOST} "df -kh | grep home | awk '{print \$4}' | cut -d \".\" -f1")
}

search()
{
# Function to search particular pattern from fetched logs 
if [ ${AUTO_SEARCH} = "true" ]
then
	while read line
	do
		CMD_TO_RUN="zgrep --color=always -C2 '${line}' ${LOGS_TO_FETCH}*"
		#CMD_TO_RUN="zgrep -B1 '${line}' ${LOGS_TO_FETCH}*"
                echo -e "\n---------------------------- ${line} ${DATE} ${HOST} ---------------------------------" >>${OUTPUT_PATH}/s3_logs_fetch.log-${TDATE}
		ssh -l ${REMOTE_USER} ${REMOTE_HOST} "${CMD_TO_RUN}" >>${OUTPUT_PATH}/s3_logs_fetch.log-${TDATE} </dev/null
	done<${INPUT_FILE}
else
	read -t40 -p "Enter complete command to be executed on fetched logs: " READ
	if [ ${?} -eq 142 ]
	then
		echo -e "\e[1;31m\nSEARCH_FUNCTION::: ERROR :: TIMEOUT :: No Input given by user to search from logs\e[0m \n"
		errors
		exit 1
	else
		ssh -l rajat_23142 10.4.44.125 "${READ}" >>${OUTPUT_PATH}/s3_logs_fetch.log-${TDATE} 2>/dev/null
	fi
fi
}


remove()
{
	echo -e "\nGoing to remove logs from staging server ${REMOTE_HOST} for ${HOST}"
	ssh -l rajat_23142 10.4.44.125 "rm -rv ${LOGS_TO_FETCH}*" > output_files/s3/remove_func.log-${TDATE} 2>&1
	if [[ ${?} -ne 0 ]]
	then
		echo -e "\n\e[1;31m\nREMOVE_FUNCTION::: ERROR :: LOGS_REMOVE :: Logs could not be removed from staging.\e[0m \n"
		errors
		exit 1
	fi
}

fetch()
{
	## Fetch logs from AWS S3 Bucket on 10.4.44.125 to Path /home/rajat_23142
	CDATE=$(echo "${DATE}" | tr ',' ' ')
	for DATE in ${CDATE}
	do
		SEPHOST=$(echo "${HOSTNAME}" | tr ',' ' ')
		for HOST in ${SEPHOST}
		do
			bucket_size_check
			echo "Space available on staging server is ${AVAILABLE_SPACE}G"
			echo "Space of logs is ${BUCKET_SIZE}G"
			if [[ ${AVAILABLE_SPACE} -lt ${BUCKET_SIZE} ]]
			then
				echo "Space is less on staging, logs cannot be fetched for ${HOST}"
				continue
			fi
			echo -e "\nFETCH_FUNCTION::: Going to fetch S3 logs for DATE: ${DATE} HOST: ${HOST}\n"
			ssh -l ${USER_NAME} ${REMOTE_HOST} "aws s3 sync s3://digital-onuslogsarchive-180/${BUCKET}/${DATE}/${HOST}/ . --exclude '*' --include '${LOGS_TO_FETCH}*'" >output_files/s3/fetch_func.log-${TDATE} 2>&1
			if [[ ${?} -ne 0 ]]
			then
				echo -e "\e[1;31m\nFETCH_FUNCTION::: ERROR :: LOGS_FETCH :: Script was not able to fetch files from S3 Bucket from Host ${HOST}\e[0m \n"
				errors
				exit 1
			else
				FETCH_LOG_CHECK=$(ssh -l ${USER_NAME} ${REMOTE_HOST} "ls -ltrh ${LOGS_TO_FETCH}* | wc -l" 2>/dev/null)
				if [ ${FETCH_LOG_CHECK} -eq 0 ]
				then
					echo -e "FETCH_FUNCTION::: S3 logs ${LOGS_TO_FETCH} not available for HOST: ${HOST} for DATE: ${DATE}"
				else
					echo -e "FETCH_FUNCTION::: Logs fetched successfully for DATE: ${DATE} HOST: ${HOST}\n"
				fi
			fi
		
			if [ ${SEARCH_FLAG} = "true" ]
			then
				search
			fi

			if [ ${REMOVE_FLAG} = "false" ]
			then
				exit 1
			elif [ ${REMOVE_FLAG} = "true" ]
			then
				remove
			else
				echo "Invalid REMOVE FLAG set. Use 'true' or 'false'"
			fi
		done
	done
}

##Check config exist or not. read config if exist

if [ -f input_files/s3/s3.cfg ]
then
source input_files/s3/s3.cfg
else
echo -e "\e[1;31mERROR :: CONFIG_MISS :: config file doesn't exist\e[0m \n"
errors
exit 1
fi

##Check all three flags

if [ ${FETCH_FLAG} = "false" -a ${SEARCH_FLAG} = "false" -a ${REMOVE_FLAG} = "false" ]
then
echo -e "All flags configured are false.\n"
usage
exit 1
fi

##Checking bucket configured by user is correct or not

if [ ${BUCKET} = "dcat-kafka-consumer" -o ${BUCKET} = "dcat-server" -o ${BUCKET} = "digital-bfsigw" -o ${BUCKET} = "digital-booking-engine" -o ${BUCKET} = "digital-catalog" -o ${BUCKET} = "digital-datasync" -o ${BUCKET} = "digital-deferred" -o ${BUCKET} = "digital-ebps" -o ${BUCKET} = "digital-edugw" -o ${BUCKET} = "digital-favourite" -o ${BUCKET} = "digital-ffrblue" -o ${BUCKET} = "digital-ffrgreen" -o ${BUCKET} = "digital-ffrjobs" -o ${BUCKET} = "digital-ffrorderactions" -o ${BUCKET} = "digital-ffrorderclear" -o ${BUCKET} = "digital-ffrutil" -o ${BUCKET} = "digital-ffrweb" -o ${BUCKET} = "digital-forms" -o ${BUCKET} = "digital-ingw" -o ${BUCKET} = "digital-inmnp" -o ${BUCKET} = "digital-inoperator" -o ${BUCKET} = "digital-inrecon" -o ${BUCKET} = "digital-merchantsubscription" -o ${BUCKET} = "digital-notification" -o ${BUCKET} = "digital-recharges-express" -o ${BUCKET} = "digital-reminder-publisher" -o ${BUCKET} = "digital-reminder-subscriber" -o ${BUCKET} = "digital-reminder" -o ${BUCKET} = "digital-seller" -o ${BUCKET} = "digital-services" -o ${BUCKET} = "digital-subscription" -o ${BUCKET} = "digital-utilgw" -o ${BUCKET} = "digital_metro" -o ${BUCKET} = "ffrecharge" -o ${BUCKET} = "ffrnotifyfulfillment"  ]
then
	echo -e "Bucket is available. Going to call fetch function." ;sleep 0.2s
	if [ ${FETCH_FLAG} = "true" ]
	then
		fetch
	else
		echo "Info: FETCH_FLAG is configured as false."
	fi
else
	echo -e "\e[1;31mERROR :: INVALID_BUCKET :: No such bucket\e[0m \n"
	errors
	exit 1
fi
