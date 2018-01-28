#!/bin/bash
LOGHOST="collector.testbed.tier.internet2.edu"
LOGPORT="5001"
if [ -s /opt/tier/env.bash ]; then
  . /opt/tier/env.bash
fi

#below for syslog, F-TICKS style
#LOGTEXT="TIERBEACON/TIER/1.0#IM=$IMAGENAME#PV=$VERSION#TR=$TIERVERSION#MT=$MAINTAINER#"

#below for JSON/REST style
LOGTEXT="{ \"msgType\" : \"TIERBEACON\", \"msgName\" : \"TIER\", \"msgVersion\" : \"1.0\", \"tbProduct\" : \"$IMAGENAME\", \"tbProductVersion\" : \"$VERSION\", \"tbTIERRelease\" : \"$TIERVERSION\", \"tbMaintainer\" : \"$MAINTAINER\" }"


if [ -z "$TIER_BEACON_OPT_OUT" ]; then
  #send JSON
  echo $LOGTEXT > msgjson.txt
  curl -s -XPOST "${LOGHOST}:${LOGPORT}/" -H 'Content-Type: application/json' -T msgjson.txt 1>/dev/null
  rm -f msgjson.txt
  
  #below is for syslog, F-TICKS style
  #`logger -n $LOGHOST -P $LOGPORT -t TIERBEACON $LOGTEXT`

  echo `date`"; TIER beacon sent."
fi