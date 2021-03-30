#!/bin/bash

##
# Configuration
##

MASTER_SERVER_ADDRESS=172.31.27.154
MAILFROM="thinh1517@gmail.com"
MAILTO="thinh1517@gmail.com"
while sleep 5; do
##
# Check permissions
##

# For the root user "id -u" will always return "0"
  if [ "$(id -u)" != "0" ]
  then
    echo "This script must be run as root" 2>&1
    exit 1
  fi

##
# Check connectivity
##

  ping -c 1 "$MASTER_SERVER_ADDRESS" &> /dev/null

  # "$?" is the result code of the above ping call and 0 means that the host is reachable.
  if [ $? != 0 ]
  then
    echo "MariaDB master server is not reachable. Aborting ..."
    exit 1
  fi

##
# Check MariaDB service availability
##

  ERROR=$(mysql -h "$MASTER_SERVER_ADDRESS" -P 3306 2>&1)

  if [ "$ERROR" = "ERROR 2002 (HY000): Can't connect to MySQL server on '$MASTER_SERVER_ADDRESS' (115)" ]
  then
    echo "MariaDB master server is reachable but MariaDB service is not running. Aborting ..."
    exit 1
  fi

##
# Check replication status
##

  STATUS=$(mysql -e "SHOW SLAVE STATUS \G;")
  IO_IS_RUNNING=$(echo "$STATUS" | grep "Slave_IO_Running:" | awk '{ print $2 }')
  SQL_IS_RUNNING=$(echo "$STATUS" | grep "Slave_SQL_Running:" | awk '{ print $2 }')
  MESSAGE="/home/ec2-user/log.log"

  if [ "$IO_IS_RUNNING" = "Yes" ] && [ "$SQL_IS_RUNNING" = "Yes" ]
  then
    echo "$(date) Replication is running." >> $MESSAGE
  else
    echo "$(date) Replication is not running." >> $MESSAGE
    echo "Execute the SQL query \"SHOW SLAVE STATUS;\" for debugging information." >> $MESSAGE
    echo "You can skip a single error executing the SQL query \"SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;\"." >> $MESSAGE 
    echo -e "$SUBJECT" | mail -s "MariaDB replication ERROR encountered" -a "From: $MAILFROM" "$MAILTO" < $MESSAGE
  fi
# echo "$SUBJECT"
done