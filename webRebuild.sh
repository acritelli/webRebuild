#!/bin/bash

#Name: webRebuild.sh
#Author: Anthony Critelli
#This script installs and configures an nginx, mysql, php-fpm web server. Additional packages that I use are installed.
#This has been tested on CentOS 6.5

##########---------- Functions ----------##########

#Used for installing various programs.
#Args: package name
install_program()
{
	#Skip if already installed. This is not a great method, but works for the purpose of this script.
	rpm -qa | grep $1 &> /dev/null
	if [[ $? -ne 1 ]]
	then
		echo "[NOTICE] $1 is already installed. Skipping."
		return
	fi

	echo "[NOTICE] Attempting to install $1 with yum. See $LOGBASEDIR/yum_install_log for details."

	yum install -y $1 1>> $LOGBASEDIR/yum_install_log 2>> $LOGBASEDIR/yum_install_error_log

	if [[ $? -ne 0 ]]
	then
		echo "[ERROR] Problem installing $1. See $LOGBASEDIR/yum_install_error_log for more info." 1>&2
	else
		echo "[NOTICE] Successfully installed package $1."
	fi
}

#Used for turning on services for runlevels with chkconfig.
#Args: service name
chkconfig_on()
{
	chkconfig $1 on &> /dev/null
	if [[ $? -ne 0 ]]
	then
		echo "[ERROR] Problem with chkconfig $1 on." 1>&2
	else
		echo "[NOTICE] chkconfig $1 successful."
	fi
}

###################################################

#Variables
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Credit to Dave Dopson for this one-liner
LOGBASEDIR=/tmp/webBuildLogs
HOSTNAME=server1.example.com
EPELREPO=http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
REGULARUSER=tony
NGINXSERVERNAME='127.0.0.1 *.example.com' #This is placed into the nginx server block
WEBDIR=/var/www/example.com

#Repo for nginx
read -d '' NGINXREPO << EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/6/\$basearch/
gpgcheck=0
enabled=1
EOF

#Repo for MariaDB
read -d '' MARIAREPO << EOF
\# MariaDB 10.0 CentOS repository list - created 2014-05-19 16:58 UTC
\# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

#Login banner for /etc/issue
read -d '' ISSUEBANNER << EOF

This is a protected system. Unauthorized use of this system will be prosecuted to the fullest extent of the law. All activities while using this system are subject to logging. You should have no expectation of privacy while using this system.


IF YOU ARE NOT AUTHORIZED TO USE THIS SYSTEM, THEN LEAVE NOW.
EOF

#This script must be run as root.
if [[ $EUID -ne 0 ]]
then
	echo "[ERROR] This script must be run as root" 1>&2
	exit 1
fi

#Make sure all variables are actually set.
if [ -z "$SCRIPTDIR" ] || [ -z "$LOGBASEDIR" ] || [ -z "$HOSTNAME" ] || [ -z "$EPELREPO" ] || [ -z "$REGULARUSER" ] || [ -z "$NGINXSERVERNAME" ] || [ -z "$WEBDIR" ] || [ -z "$NGINXREPO" ] || [ -z "$MARIAREPO" ] || [ -z "$ISSUEBANNER" ]
then
	echo "[ERROR] Some variable is not set. Ensure that all variables in script are set."
	exit 1
fi


#Create base directory for storing logs
if [[ ! -d $LOGBASEDIR ]]
	then
		mkdir $LOGBASEDIR &> /dev/null
		if [[ $? -ne 0 ]]
		then
			echo "[ERROR] Unable to create location for log files at $LOGBASEDIR. Log files will not be saved." 1>&2
		else
			echo "[NOTICE] Created $LOGBASEDIR. Various log files can be found here."
		fi
	else
		echo "[NOTICE] $LOGBASEDIR already exists. Saving logfiles to this location."
fi
	

#Change hostname
echo "[NOTICE] Changing hostname to $HOSTNAME" && sed -i '/^HOSTNAME/ d' /etc/sysconfig/network &> /dev/null && echo "HOSTNAME=$HOSTNAME" >> /etc/sysconfig/network
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem changing hostname in /etc/sysconfig/network" 1>&2
fi

#Install pre-login banner to /etc/issue
echo "$ISSUEBANNER" > /etc/issue
if [[ $! -ne 0 ]]
then
	echo "[ERROR] Unable to update /etc/issue. Banner not changed." 1>&2
else
	echo "[NOTICE] SSH banner updated in /etc/issue"
fi


#Install updates
echo "[NOTICE] Attempting to install updates with yum. See $LOGBASEDIR/yum_update_log for details."
yum update -y 1>> $LOGBASEDIR/yum_update_log 2>> $LOGBASEDIR/yum_update_error_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem with updating packages. See /tmp/yum_update_error for more details." 1>&2
fi

##########---------- Program Installation ----------##########

#Add EPEL and install fail2ban, clamav, and clamd
yum repolist | grep ^epel &> /dev/null
if [[ $? -ne 0 ]]
	then
		rpm -Uvh $EPELREPO &> /dev/null
		if [[ $? -ne 0 ]]
		then
			echo "[ERROR] Unable to add EPEL repo. Certain packages may not be installed." 1>&2
		fi
fi


install_program fail2ban
install_program clamav
install_program clamd


#Install nginx, adding repos per nginx documentation
echo "$NGINXREPO" > /etc/yum.repos.d/nginx.repo
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Unable to add nginx repo to /etc/yum.repos.d/nginx.repo. Installation of nginx failed." 1>&2
else
	install_program nginx
fi

#Install maria db
echo "$MARIAREPO" > /etc/yum.repos.d/MariaDB.repo
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Unable to add MariaDB repo to /etc/yum.repos.d/MariaDB.repo. Installation of MariaDB failed." 1>&2
else
	install_program MariaDB-server 
	install_program MariaDB-client
fi


install_program php-fpm

install_program tmpwatch

install_program ntpd

install_program ntpdate

##############################################################

#Chkconfig various programs on
chkconfig_on fail2ban
chkconfig_on nginx
chkconfig_on php-fpm
chkconfig_on mysql
chkconfig_on clamd
chkconfig_on iptables
chkconfig_on sshd
chkconfig_on ntpd


##########---------- Install Config Files ----------##########

#Install cron.daily jobs
cp $SCRIPTDIR/configs/cron/cron.daily/* /etc/cron.daily/ &>> $LOGBASEDIR/config_install_log && chown root:root /etc/cron.daily/* &>> $LOGBASEDIR/config_install_log && chmod 755 /etc/cron.daily/* &>> $LOGBASEDIR/config_install_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem moving scripts to cron.daily. See $LOGBASEDIR/config_install_log for details." 1>&2
else
	echo "[NOTICE] Successfully added scripts to cron.daily."
fi

#Install nginx configs
tar -xf $SCRIPTDIR/configs/nginxBackup.tgz -C /etc/ &>> $LOGBASEDIR/config_install_log && ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/ &>> $LOGBASEDIR/config_install_log && chown -R root:root /etc/nginx/ &>> $LOGBASEDIR/config_install_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem restoring /etc/nginx/. See $LOGBASEDIR/config_install_log for details." 1>&2
else
	echo "[NOTICE] Successfully restored /etc/nginx/"
fi

#Get ip address and place into site configs for nginx
IPADDR=$(curl --silent icanhazip.com) && sed -i "s/server_name.*/server_name $IPADDR $NGINXSERVERNAME;n/" /etc/nginx/sites-available/* &>> $LOGBASEDIR/config_install_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem setting server_name in sites-available. See $LOGBASEDIR/config_install_log for details." 1>&2
else
	echo "[NOTICE] Successfully set server_name in sites-available. Box IP address is $IPADDR"
fi

#Install php-fpm configs
cp $SCRIPTDIR/configs/php-fpm/php-fpm.conf /etc/ &>> $LOGBASEDIR/config_install_log && cp $SCRIPTDIR/configs/php-fpm/www.conf /etc/php-fpm.d/ &>> $LOGBASEDIR/config_install_log && chown root:root /etc/php-fpm.conf &>> $LOGBASEDIR/config_install_log && chown -R root:root /etc/php-fpm.d &>> $LOGBASEDIR/config_install_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem restoring php-fpm configs. See $LOGBASEDIR/config_install_log for details." 1>&2
else
	echo "[NOTICE] Successfully restored php-fpm configs"
fi

#Install iptables configs
cp $SCRIPTDIR/configs/iptables /etc/sysconfig/ &>> $LOGBASEDIR/config_install_log && chown root:root /etc/sysconfig/iptables &>> $LOGBASEDIR/config_install_log && chmod 600 /etc/sysconfig/iptables &>> $LOGBASEDIR/config_install_log
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem restoring iptables config. See $LOGBASEDIR/config_install_log for details." 1>&2
else
	echo "[NOTICE] Successfully restored iptables configs"
fi

#Install Wordpress
if [[ -d $WEBDIR ]]
then
	echo "[NOTICE] $WEBDIR already exists. Skipping installation of Wordpress files."
else
	mkdir -p $WEBDIR &>> $LOGBASEDIR/config_install_log && curl --silent wordpress.org/latest.zip > /tmp/wordpressInstall.zip 2>> $LOGBASEDIR/config_install_log && unzip /tmp/wordpressInstall.zip -d $WEBDIR &>> $LOGBASEDIR/config_install_log
	if [[ $? -ne 0 ]]
	then
		echo "[ERROR] Problem installing Wordpress files. See $LOGBASEDIR/config_install_log for details." 1>&2
	else
		echo "[NOTICE] Successfully installed Wordpress files"
	fi
fi

##############################################################

#Add a regular user
useradd $REGULARUSER &> /dev/null
if [[ $? -ne 0 ]]
then
	echo "[ERROR] Problem adding regular user $REGULARUSER" 1>&2
else
	echo "[NOTICE] Successfully added regular user $REGULARUSER"
fi

echo "[NOTICE] Script completed. Review any errors before proceeding."

echo "

The script has completed running. Review any errors before proceeding.
***YOU MUST STILL COMPLETE THE FOLLOWING TASKS***
Change the password for $REGULARUSER
Add $REGULARUSER to sudoers file
Change the mysql root password
Place the necessary certificates in the /etc/nginx/certs directory
Configure SSH as desired - remove root access, add $REGULARUSER, and configure any desired keys
Delete the contents of /tmp/webBuildLogs
Restart this server

Upon restart, you should be able to configure Wordpress and restore any appropriate Wordpress backups.

"