#!/bin/bash
#
# This script generates a new sealer keystore with a new random password and configures the IdP to use it.
# It is designed to be run when the shibboleth_idp container is built/rebuilt, which would ensure that multiple containers reamin in sync (same key, same pwd)
# 

# default directories
TOMCFG=config/tomcat
TOMLOG=logs/tomcat
TOMCERT=credentials/tomcat
TOMWWWROOT=wwwroot
SHBCFG=config/shib-idp/conf
SHBCREDS=credentials/shib-idp
SHBVIEWS=config/shib-idp/views
SHBEDWAPP=config/shib-idp/edit-webapp
SHBMSGS=config/shib-idp/messages
SHBMD=config/shib-idp/metadata
SHBLOG=logs/shib-idp

STARTDIR=$(pwd)
CRYPTODIR=tmp_crypto
LOGFILE=sealer-gen.log
IDP_PROP=${SHBCFG}/idp.properties
IDP_SEALER_FILE=${SHBCREDS}/sealer.jks

#
# build the shibboleth sealer java keystore
#
echo ""
echo "Creating new Shibboleth sealer keystore..."
echo ""
#
mkdir -p ${CRYPTODIR}
cd ${CRYPTODIR}
SEALERPWD=$(uuidgen)
keytool -genseckey -storetype jceks -alias secret1 -providername SunJCE -keyalg AES -keysize 256 -storepass ${SEALERPWD} -keypass ${SEALERPWD} -keystore mysealer.jks >> ${LOGFILE} 2>&1
cp -f mysealer.jks ${IDP_SEALER_FILE}
cd ${STARTDIR}
#
#
# updates to idp.properties to configure the auto-generated sealer password
#	
echo ""
echo "Updating idp.properties with new sealer keystore password."
echo ""

cp -f ${IDP_PROP} ${IDP_PROP}.tmp

sed '/idp.sealer.storePassword/c\
idp.sealer.storePassword= '${SEALERPWD} ${IDP_PROP}.tmp > ${IDP_PROP}.tmp2

sed '/idp.sealer.keyPassword/c\
idp.sealer.keyPassword= '${SEALERPWD} ${IDP_PROP}.tmp2 > ${IDP_PROP}

rm -f ${IDP_PROP}.tmp2
rm -f ${IDP_PROP}.tmp

rm -rf ${CRYPTODIR}/*
rmdir ${CRYPTODIR}
echo ""
echo "The new sealer key was successfully generated and a new random password configured in idp.properties."
echo ""
echo "If you utilize a burned-in config, then you can now build a new image from this config."
echo ""


