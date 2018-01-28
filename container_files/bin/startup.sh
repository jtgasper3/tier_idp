#!/bin/bash
CRONFILE=/opt/tier/tier-cron

#set env vars for cron job
/opt/tier/setenv.sh

#build crontab file with random start time between midnight and 3:59am
echo "#send daily beacon to TIER Central" > ${CRONFILE}
echo $(expr $RANDOM % 59) $(expr $RANDOM % 3) "* * * /usr/bin/sendtierbeacon.sh >> /var/log/cron.log 2>&1" >> ${CRONFILE}
chmod 644 ${CRONFILE}

#install crontab
crontab ${CRONFILE}

#create cron logfile
touch /var/log/cron.log

#start crond
/usr/sbin/crond

#start tomcat
/usr/local/tomcat/bin/catalina.sh run
