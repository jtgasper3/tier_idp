FROM centos:centos7

########################
### VERSION SETTINGS ###
########################
#
##java
ENV JAVA_VERSION=8u162
ENV BUILD_VERSION=b12
ENV JAVA_BUNDLE_ID=0da788060d494f5095bf8624735fa2f1
##tomcat
ENV TOMCAT_MAJOR=8
ENV TOMCAT_VERSION=8.0.49
##shib-idp
ENV VERSION=3.3.2
##TIER
ENV TIERVERSION=17110

##################
### OTHER VARS ###
##################
#
#global
ENV IMAGENAME=shibboleth_idp
ENV MAINTAINER=tier
#java
ENV JAVA_HOME=/usr/java/latest
ENV JAVA_OPTS=-Xmx3000m -XX:MaxPermSize=256m
#tomcat
ENV CATALINA_HOME=/usr/local/tomcat
ENV TOMCAT_TGZ_URL=https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
ENV PATH=$CATALINA_HOME/bin:$JAVA_HOME/bin:$PATH
#shib-idp
ENV SHIB_RELDIR=http://shibboleth.net/downloads/identity-provider/$VERSION
ENV SHIB_PREFIX=shibboleth-identity-provider-$VERSION

#set labels
LABEL Vendor="Internet2"
LABEL ImageType="Shibboleth IDP Release"
LABEL ImageName=$imagename
LABEL ImageOS=centos7
LABEL Version=$VERSION



#########################
### BEGIN IMAGE BUILD ###
#########################
#
# Set UTC Timezone & Networking
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "NETWORKING=yes" > /etc/sysconfig/network

# Install base deps
RUN rm -fr /var/cache/yum/* && yum clean all && yum -y install --setopt=tsflags=nodocs epel-release && \
    yum -y install net-tools wget curl tar unzip mlocate logrotate strace telnet man unzip vim wget rsyslog cron krb5-workstation openssl-devel wget && \
    yum -y clean all && \
    mkdir -p /opt/tier

# Install Trusted Certificates
RUN update-ca-trust force-enable
ADD container_files/cert/InCommon.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust extract

# TIER Beacon Opt-out
# Completely uncomment the following ENV line to prevent the containers from sending analytics information to Internet2.
# With the default/release configuration, it will only send product (Shibb/Grouper/COmanage) and version (3.3.1-17040, etc) 
#   once daily between midnight and 4am.  There is no configuration or private information collected or sent.  
# This data helps with the scalaing and funding of TIER.  Please do not disable it if you find the TIER tools useful.
# To keep it commented, keep multiple comments on the following line (to prevent other scripts from processing it).
#####     ENV TIER_BEACON_OPT_OUT True


# Install java/JCE
#
# Uncomment the following commands to download the JDK to your Shibboleth IDP image.  
#     ==> By uncommenting these next 6 lines, you agree to the Oracle Binary Code License Agreement for Java SE (http://www.oracle.com/technetwork/java/javase/terms/license/index.html)
RUN wget -nv --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$JAVA_VERSION-$BUILD_VERSION/$JAVA_BUNDLE_ID/jdk-$JAVA_VERSION-linux-x64.rpm" -O /tmp/jdk-$JAVA_VERSION-$BUILD_VERSION-linux-x64.rpm && \
     yum -y install /tmp/jdk-$JAVA_VERSION-$BUILD_VERSION-linux-x64.rpm && \
     rm -f /tmp/jdk-$JAVA_VERSION-$BUILD_VERSION-linux-x64.rpm && \
     alternatives --install /usr/bin/java jar $JAVA_HOME/bin/java 200000 && \
     alternatives --install /usr/bin/javaws javaws $JAVA_HOME/bin/javaws 200000 && \
     alternatives --install /usr/bin/javac javac $JAVA_HOME/bin/javac 200000

# Uncomment the following commands to download the Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files.  
#     ==> By uncommenting these next 8 lines, you agree to the Oracle Binary Code License Agreement for Java SE Platform Products (http://www.oracle.com/technetwork/java/javase/terms/license/index.html)
 RUN yum -y install unzip \
     && wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
     http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip \
     && echo "f3020a3922efd6626c2fff45695d527f34a8020e938a49292561f18ad1320b59  jce_policy-8.zip" | sha256sum -c - \
     && unzip -oj jce_policy-8.zip UnlimitedJCEPolicyJDK8/local_policy.jar -d $JAVA_HOME/jre/lib/security/ \
     && unzip -oj jce_policy-8.zip UnlimitedJCEPolicyJDK8/US_export_policy.jar -d $JAVA_HOME/jre/lib/security/ \
     && rm jce_policy-8.zip \
     && chmod -R 640 $JAVA_HOME/jre/lib/security/

# Copy IdP installer properties file(s)
ADD container_files/idp/idp.installer.properties /tmp/idp.installer.properties
ADD container_files/idp/idp.merge.properties /tmp/idp.merge.properties
ADD container_files/idp/ldap.merge.properties /tmp/ldap.merge.properties
		   
# Install IdP
RUN mkdir -p /tmp/shibboleth && cd /tmp/shibboleth && \
      wget -q https://shibboleth.net/downloads/PGP_KEYS \
           $SHIB_RELDIR/$SHIB_PREFIX.tar.gz \ 
           $SHIB_RELDIR/$SHIB_PREFIX.tar.gz.asc \
           $SHIB_RELDIR/$SHIB_PREFIX.tar.gz.sha256 && \
# Perform verifications
           gpg --import PGP_KEYS && \
           gpg $SHIB_PREFIX.tar.gz.asc && \
           sha256sum --check $SHIB_PREFIX.tar.gz.sha256 && \
# Unzip
           tar xf $SHIB_PREFIX.tar.gz && \
# Install
           cd /tmp/shibboleth/$SHIB_PREFIX && \
		   ./bin/install.sh \
               -Didp.noprompt=true \
			   -Didp.property.file=/tmp/idp.installer.properties && \
# Cleanup
           rm -rf /tmp/shibboleth


# Install tomcat           
RUN mkdir -p "$CATALINA_HOME"

## Not having trouble with this locally [JVF]
## see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
## RUN set -ex \
##     && for key in \
##         05AB33110949707C93A279E3D3EFE6B686867BA6 \
##         07E48665A34DCAFAE522E5E6266191C37C037D42 \
##         47309207D818FFD8DCD3F83F1931D684307A10A5 \
##         541FBE7D8F78B25E055DDEE13C370389288584E7 \
##         61B832AC2F1C5A90F0F9B00A1C506407564C17A3 \
##         713DA88BE50911535FE716F5208B0AB1D63011C7 \
##         79F7026C690BAA50B92CD8B66A3AD3F4F22C4FED \
##         9BA44C2621385CB966EBA586F72C284D731FABEE \
##         A27677289986DB50844682F8ACB77FC2E86E29AC \
##         A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 \
##         DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 \
##         F3A04C595DB5B6A5F1ECA43E3B7BBB100D811BBE \
##         F7DA48BB64BCB84ECBA7EE6935CD23C10D498E23 \
##     ; do \
##         gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
##     done

#WORKDIR $CATALINA_HOME
RUN set -x \
	&& wget -q -O $CATALINA_HOME/tomcat.tar.gz "$TOMCAT_TGZ_URL" \
	&& wget -q -O $CATALINA_HOME/tomcat.tar.gz.asc "$TOMCAT_TGZ_URL.asc" \
#	&& gpg --batch --verify $CATALINA_HOME/tomcat.tar.gz.asc $CATALINA_HOME/tomcat.tar.gz \
	&& tar -xvf $CATALINA_HOME/tomcat.tar.gz -C $CATALINA_HOME --strip-components=1 \
	&& rm $CATALINA_HOME/bin/*.bat \
	&& rm $CATALINA_HOME/tomcat.tar.gz* \
    && mkdir -p $CATALINA_HOME/conf/Catalina \
    && curl -o /usr/local/tomcat/lib/jstl1.2.jar https://build.shibboleth.net/nexus/service/local/repositories/thirdparty/content/javax/servlet/jstl/1.2/jstl-1.2.jar
ADD container_files/idp/idp.xml /usr/local/tomcat/conf/Catalina/idp.xml
ADD container_files/tomcat/server.xml /usr/local/tomcat/conf/server.xml
RUN rm -rf /usr/local/tomcat/webapps/* && \
    ln -s /opt/shibboleth-idp/war/idp.war $CATALINA_HOME/webapps/idp.war

	
	
# Copy TIER helper scripts
ADD container_files/bin/setenv.sh /opt/tier/setenv.sh
RUN chmod +x /opt/tier/setenv.sh
ADD container_files/bin/startup.sh /usr/bin/startup.sh
RUN chmod +x /usr/bin/startup.sh
ADD container_files/bin/sendtierbeacon.sh /usr/bin/sendtierbeacon.sh
RUN chmod +x /usr/bin/sendtierbeacon.sh


###############################################
### Settings for a mounted config (default) ###
###############################################
VOLUME ["/usr/local/tomcat/conf", \
	    "/usr/local/tomcat/webapps/ROOT", \
		"/usr/local/tomcat/logs", \
		"/opt/certs", \
		"/opt/shibboleth-idp/conf", \
		"/opt/shibboleth-idp/credentials", \
		"/opt/shibboleth-idp/views", \
		"/opt/shibboleth-idp/edit-webapp", \
		"/opt/shibboleth-idp/messages", \
		"/opt/shibboleth-idp/metadata", \
		"/opt/shibboleth-idp/logs"]


#################################################
### Settings for a burned-in config (default) ###
#################################################		
# Conversely, for a burned config, *uncomment* the COPY lines below and *comment* the lines of the VOLUME command above
#
# consider not doing the volumes below as it creates a run-time dependency and a better solution might be to use syslog from the container
# VOLUME ["/usr/local/tomcat/logs", "/opt/shibboleth-idp/logs"]
#
# ensure the following locations are accurate if you plan to burn your configuration into your containers by uncommenting the relevant section below
# they represent the folder names/paths on your build host of the relevant config material needed to run the container
# The paths below must be relative to (subdirectories of) the directory where the Dockerfile is located.
# The paths below are just the default values.  They are typically overriden by "build-args" in the 'docker build' command.
ARG TOMCFG=config/tomcat
ARG TOMLOG=logs/tomcat
ARG TOMCERT=credentials/tomcat
ARG TOMWWWROOT=wwwroot
ARG SHBCFG=config/shib-idp/conf
ARG SHBCREDS=credentials/shib-idp
ARG SHBVIEWS=config/shib-idp/views
ARG SHBEDWAPP=config/shib-idp/edit-webapp
ARG SHBMSGS=config/shib-idp/messages
ARG SHBMD=config/shib-idp/metadata
ARG SHBLOG=logs/shib-idp
#
## ADD ${TOMCFG} /usr/local/tomcat/conf
## ADD ${TOMCERT} /opt/certs
## ADD ${TOMWWWROOT} /usr/local/tomcat/webapps/ROOT
## ADD ${SHBCFG} /opt/shibboleth-idp/conf
## ADD ${SHBCREDS} /opt/shibboleth-idp/credentials
## ADD ${SHBVIEWS} /opt/shibboleth-idp/views
## ADD ${SHBEDWAPP} /opt/shibboleth-idp/edit-webapp
## ADD ${SHBMSGS} /opt/shibboleth-idp/messages
## ADD ${SHBMD} /opt/shibboleth-idp/metadata

# Expose the port tomcat will be serving on
EXPOSE 443

#establish a healthcheck command so that docker might know the container's true state
HEALTHCHECK --interval=2m --timeout=30s \
  CMD curl -k -f https://127.0.0.1/idp/status || exit 1
  

# Start tomcat/crond
CMD ["/usr/bin/startup.sh"]
