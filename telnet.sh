#!/bin/bash

datetime=$(date +%F-%N)
#wait for N seconds to check the connection then terminate the telnet command
TIMEOUT="5"
OPERATOR_IP="${2}"
OPERATOR_PORT="${3}"
NO_OF_LOOPS="20"

if [ ${#} -eq 0 -o ${#} -eq 1 -o ${#} -eq 2 ]
then
	echo -e "Usage:: ${0} [telnet_status or netcat_status] [IP OR DNS] [PORT]"
	exit 1
fi

telnet_status()
{
	#connectivity check using telnet command
	i=0;
	while [[ i -lt ${NO_OF_LOOPS} ]]
	do
		let i=i+1
		echo -e "counter: ${i}"
		if echo | date ; timeout ${TIMEOUT} telnet ${OPERATOR_IP} ${OPERATOR_PORT} | grep Connected
		then
			echo -e "\n\n\e[1;32mtelnet.ok\e[0m\n\n"
		else
			echo -e "\n\n\e[1;31mtelnet.nok\e[0m\n\n"
		fi
	done
}

netcat_status()
{
	#connectivity check using netcat command
	i=0;
	while [[ i -lt ${NO_OF_LOOPS} ]]
	do
		let i=i+1
		echo -e "counter: ${i}"
		date;nc -v ${OPERATOR_IP} ${OPERATOR_PORT} -w ${TIMEOUT}
		if [ ${?} -eq 0 ]
		then
			echo -e "\n\n\e[1;32mtelnet.OK\e[0m\n\n"
		else
			echo -e "\n\n\e[1;31mtelnet.NOK\e[0m\n\n"
		fi
	done
}

CALL_FUNCTION="${1}"

#${FUNCTION_TO_CALL} -s  2>&1  | tee connectivity-status.out-${datetime}

${CALL_FUNCTION} >>connectivity-status.out-${datetime} 2>&1
