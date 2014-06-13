#########################################################
########## Server Performance Check Script ##############
############### Runs for RHEL & equal ###################
#### This Script is Built with basic System Commands ####
#########################################################
#########################################################
#########################################################
#########################################################
#########################################################
########### Prerequirements "Sysstat" ###################
#########################################################
#######Author & Publisher "Subhankar" ISST ############
############ Linux_Perfcheck.sh Version 1 ###############
#########################################################
#########################################################
#########################################################

#!/bin/bash
MAX_PROCESS=700
MEMORY_THRESHOLD=75
flag=y
#function 1: OS check
check_os() {
  if [ $(uname) != "Linux" ]
  then
    echo "$(basename $0) works only on Linux."
    echo "exiting ..."
    exit 10
  fi
}

#function 2: Check NFS data transfer rate
check_nfs_data_transfer_rate()
{
  echo
  echo "-----------------------------"
  echo "Checking NFS data transfer speed by copying a 10MB file .."
  echo "-----------------------------"
  echo
  echo "ATTENTION: Watch out for values of \"real time\" in the below output, if it is greater than .40 sec,"
  echo "then NFS transfer rate is 20MB/sec or less.  In that case you need to do the following:"
  echo "1. Check mount options"
  echo "2. Check filer side"
  echo "3. If OS CPU usage and load is high, that could also lead to reduced NFS transfer rate,"
  echo "in that case you need to fix OS health first."
  echo
  echo "creating 10MB file ..."
  dd if=/dev/zero of=/root/10mbfile$$ bs=1M count=10
  echo "10MB file /root/10mbfile$$ created."
  echo
  FILERLIST=$(mount -t nfs|egrep -v '(autofs|interface|stage|ro,)'|awk -F ":" '{print $1}'|sort|uniq)
  echo "This host has mounts for instance filesystems from following filers:"
  echo ${FILERLIST}|sed 's/ /,/'
  echo
  echo "Start NFS file transfer speed test, watch out now .."
  echo "-----------------------------"
  for i in ${FILERLIST}
  do
    FS=$(mount -t nfs|egrep -v '(autofs|interface|stage|ro,)'|grep ${i}|awk '{print $3}')
    echo "copying 10mbfile \"10mbfile$$\" to"
    echo "  ${FS} "
    echo "to check NFS data transfer rate ......"
        for j in ${FS}
        do
                echo
                time -p cp -f /root/10mbfile$$ $j
                echo
                echo "deleting $j/10mbfile$$"
                rm -f ${j}/10mbfile$$
       done
  done
  echo "deleting /root/10mbfile$$"
  rm -f /root/10mbfile$$
  echo "End NFS file transfer speed test .."
  echo "-----------------------------"
}

#function 3: check memory usage
check_mem_usage() {
  echo "-----------------------------"
  echo "Checking memory usage .."
  echo "-----------------------------"
  MEM_USAGE_TOTAL=$(sar -r 2 2 |tail -1|awk '{print $4}'|awk -F '.' '{print $1}')
  MEM_USAGE_ACTUAL=$(expr `free -m | grep -i "+" | awk '{print $3}'` '*' 100 '/' `free -m | grep -i mem | awk '{print $2}'`)
  if [ ${MEM_USAGE_ACTUAL} -ge ${MEMORY_THRESHOLD} ]
  then
    echo "WARNING: Actual memory usage is high, ${MEM_USAGE_ACTUAL}%."
    flag=n
    echo
    echo "most memory consuming processes are:"
    ps -eo size,pid,user,args --sort -size|head -10
    echo
    echo "Action to be taken:"
    echo "Please check which processes are consuming most of memory."
    echo "To get this information, easy way is to run top, then press \"M\""
    echo "If Application processes are using high memory then contact owning team to tune application"
    echo
  else
    echo "Memory Usage TOTAL, ${MEM_USAGE_TOTAL}% is ok."
    echo "Memory usage ACTUAL, ${MEM_USAGE_ACTUAL}% is ok."
  fi
  echo
}

#function 4: check number of processes
check_num_of_processes() {
  # checking number of non root processes, if processes is greater than
  # 700, DBA's need to tune application
  echo "-----------------------------"
  echo "Checking number of non-root processes .."
  echo "-----------------------------"
  NO_PROCESSES=$(ps -U root -u root -N|wc -l)
  if [ ${NO_PROCESSES} -ge ${MAX_PROCESS} ]
  then
    echo "WARNING: number of processes are high, ${NO_PROCESSES}, DBA's need to tune application."
    flag=n
  else
    echo "number of processes are normal, ${NO_PROCESSES}."
  fi
}


# 5: check swap partitions
check_swap_partitions() {
  # checking what all swap partitions are activated
  echo "-----------------------------"
  echo "Checking swap partitions .."
  echo "-----------------------------"
  m=`free |grep -i mem| awk '{print $2}'`
  echo "Free Memory is $m KB"
  j=0
  for i in `swapon -s | grep -v Size | awk '{print $3}'`
  do
       j=`expr $j + $i`
  done
  echo "total SWAP count is $j KB"

if [ $j -lt `expr $m '*' 15 '/' 10` ]
  then
    echo "WARNING: All  swap partitions are not according to memory, please check."
    echo " Current status of SWAP partitions are"
    swapon -s
    flag=n
  else
    echo "All swap paritions are activated properly."
  fi
}

#function 6: check ethernet settings
check_eth_settings() {
  # checking Ethernet settings like auto-negotiation, speed and duplex using ethtool
  echo "-----------------------------"
  echo "Checking ethernet settings .."
  echo "-----------------------------"
  for i in $(ifconfig |awk '/^eth/ {print $1}')
  do
    if ethtool ${i}|egrep '('Auto-negotiation:.*on'|'Duplex:.*Full'|'Speed:.*100')' >/dev/null
    then
       echo "Ethernet setting for ${i} is ok."
    else
       echo "WARNING: Please check Ethernet settings for ${i}."
       flag=n
    fi
  done
}

#function 7: check load average
check_load_avg() {
  echo "-----------------------------"
  echo "Checking load average .."
  echo "-----------------------------"
  if [ $(uptime |awk '{print $NF}'|cut -f 1 -d '.') -ge 3 ]
  then
    echo "WARNING: load is high"
    flag=n
    echo "Output of uptime command: $(uptime)"
    echo
    echo "Top 10 CPU consuming process:"
    ps -eo pcpu,pid,user,args --sort -pcpu|head -10
  else
    echo "Load is ok"
    echo "Output of uptime command: $(uptime)"
  fi
}

#function 8: check sar data
check_sar_data() {
  echo "-----------------------------"
  echo "Checking %idle value from sar information .."
  echo "-----------------------------"
  IDLE_PERCENTAGE=$(sar -u 2 10|tail -1|awk '{print $NF}'|cut -d '.' -f 1)
  if [ ${IDLE_PERCENTAGE} -le 5 ]
  then
    echo "WARNING: System is busy, bottleneck is CPU."
    flag=n
    echo "Percentage of time CPU was idle: ${IDLE_PERCENTAGE}"
  else
    echo "CPU usage is normal."
    echo "Percentage of time CPU was idle: ${IDLE_PERCENTAGE}"
  fi
  echo
  echo "-----------------------------"
  echo "Checking %iowait value from sar information:"
  echo "-----------------------------"
  IOWAIT_PERCENTAGE=$(sar -u 2 10|tail -1|awk '{print $6}'|cut -d '.' -f 1)
  if [ ${IOWAIT_PERCENTAGE} -ge 1 ]
  then
    echo "WARNING: There is more than acceptable iowait in this system"
    flag=n
    echo "Percentage of iowait: ${IOWAIT_PERCENTAGE}"
  else
    echo "There is no iowait in this system"
    echo "Percentage of iowait: ${IOWAIT_PERCENTAGE}"
  fi
}

#function 9: check to make sure that script is run as root
check_uid() {
  if [ $(id -u) -ne 0 ]
  then
    echo "$(basename $0) should be run as root."
    echo "exiting ..."
    exit 20
  fi
}

#main
if [ `test -f /usr/bin/sar;echo $?` -ne  0 ]
then	
	echo "Please Install sysstat RPM"
        exit 10
else
echo
check_os
check_uid
echo
echo -e "\t---------------------------"
echo -e "\tOS PERFORMANCE HEALTH CHECK"
echo -e "\t---------------------------"
echo
check_sar_data
echo
check_mem_usage
echo
check_load_avg
echo
check_swap_partitions
echo
check_eth_settings
echo
check_num_of_processes
echo
check_nfs_data_transfer_rate
echo
if [ $flag = "n" ]
then
  echo "-----------------------------"
  echo "CONCLUSION"
  echo "----------"
  echo "WARNING: System health is NOT ok."
  echo "Please check output where there are WARNINGS."
  echo "-----------------------------"
else
  echo "-----------------------------"
  echo "CONCLUSION"
  echo "----------"
  echo "System health is ok."
  echo "-----------------------------"
fi
fi
