#!/bin/bash
#
# This script will sync specified directories of files to all nodes in the docker swarm.
# It must be run from a/the manager node.
#


IDfile=`realpath $4`



DisplayUsage()
{
  echo "Usage:"
  echo "syncFilesToAllNodes <local config directory> <remote sub-directory name> <remote username> <filename of remote user's private key> | --help" >&2
  echo ""
}

#ensure docker is avail
command -v docker >/dev/null 2>&1 || { echo >&2 "ERROR: docker is required, but doesn't appear to be installed.  Aborting..."; exit 1; }


#check if running on a manager node
docker node ls > /dev/null 2>&1
if [ $? = 1 ]; then
 echo "This script must be run from a manager node. You do not appear to be on a manager node. Terminating."
 exit 1
fi


if [ $1 = '--help' ]; then
  DisplayUsage
  exit 1
fi


#sanity checks
if [[ $# -ne 4 ]]; then
  DisplayUsage
  exit 1
fi

#more checks
if ! [ -e "$1" ]; then
  echo "ERROR: $1 not found, terminating." >&2
  echo ""
  exit 1
fi
if ! [ -d "$1" ]; then
  echo "ERROR: $1 is not a directory, terminating." >&2
  echo ""
  exit 1
fi
if ! [ -e "$4" ]; then
  echo "ERROR: $4 not found, terminating." >&2
  echo ""
  exit 1
fi


#cd to specified dir (so that scp -r works as intended)
pushd $1 > /dev/null


#check if specified config dir contains the needed sub-directories
if ! [ -d "$PWD/config/shib-idp/conf" ]; then
  echo "ERROR: the specified directory does not appear to contain a valid IdP config structure, terminating."
  exit 1
fi
if ! [ -d "$PWD/config/tomcat" ]; then
  echo "ERROR: the specified directory does not appear to contain a valid Tomcat config, terminating."
  exit 1
fi


# transfer files
# get list of other nodes in the swarm
 for n in `docker node ls | sed -n '1!p' | cut -f 1 -d ' '`; do
  #echo $n
  s=$(docker node inspect --pretty $n | grep Address | cut -f 2 -d ':' | sed -n '2!p')
  thisNode=${s//[[:blank:]]/}
  echo "Connecting to ${thisNode} (`dig +noall +answer -x ${thisNode} | awk '{ print $(NF) }'`)....`scp -q -i ${IDfile} -r . $3@${thisNode}:/home/$3/$2 > /dev/null 2>&1`OK"
 done


#return to previous directory
popd > /dev/null
