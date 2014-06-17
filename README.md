This is a bash script for rebuilding a web server. I built this because occasionally my web server lights on fire, or I decide to switch providers. Rather than trying to remember my server's config and then subsequently scouring the Internet for all of the information for installing various programs, I decided to write them all up in this script. The script will also restore backup copies of configs to the appropriate locations.

This script has been tested on CentOS 6.5.

The script performs the following tasks:

1. Changes the box hostname (persistent)
2. Updates /etc/issue for the SSH banner
3. Installs updates with yum
4. Installs several other programs and services, adding repos as needed:
	* fail2ban
	* clamAV
	* clamd
	* nginx
	* MariaDB (server and client)
	* php-fpm
	* tmpwatch
	* ntpd
	* ntpdate
5. Turns on appropriate services at reboot via chkconfig
6. Restores configuration files from backup copies (see more below)
7. Downloads and installs (unzips) Wordpress to the appropriate directory
8. Adds a regular user

##Before Running

Before running the script, it is important to define various variables listed at the beginning of the script, such as $HOSTNAME. Some placeholders are included for example purposes.

Appropriate config files must also be placed in the "configs" subdirectory within the script's running directory. If you don't wish to have the script restore configs, then simply remove the appropriate sections.  See the section Configuration Restoration below for more information.

Additionally, it is recommended to have a terminal multiplexer installed, as some processes (such as yum updates) can take a significant amount of time, and you may wish to be doing other things on the system, such as tailing the log output from the script's log files.

##Configuration Restoration

Configuration files are restored from a folder named "configs" that is stored in the same directory as the script. The directory structure is shown below. Notice that within the configs directory, there is a directory for cron, a directory for php-fpm, a regular file for iptables, and a tarball for nginx configs. The method used by this script to restore files should be fairly obvious by looking at the code.
```
.
├── configs
│   ├── cron
│   │   └── cron.daily
│   │       ├── clamscan
│   │       └── freshclam
│   ├── iptables
│   ├── nginxBackup.tgz
│   └── php-fpm
│       ├── php-fpm.conf
│       └── www.conf
└── webRebuild.sh
```
It should be noted that the script doesn't just restore the nginx configs. It will also set the server_name directive in all of the /etc/nginx/sites-available files to include the IP address of the server. This works well on my single-website configurations. However, it may not be desirable for some configurations with multiple sites, and you may wish to remove this section of the script.

##Logging

When executed, the script attempts to create a base directory for logging. By default, this is /tmp/webRebuildLogs., as defined by the $LOGBASEDIR directory. Log files are created by the script. Most contain the redirected stdout and stderr output from calling commands, such as yum.

The script also logs realtime to the console. There are two types of messages: Notice and Error. Both follow the format of:

[MESSAGE_TYPE] MESSAGE

For example:

[ERROR] Problem installing package.

Notice messages are logged to stdout, while error messages are logged to STDERR. As much as possible, the script attempts to simply skip over non-critical problems and simply log them with an [ERROR] message.

##After running

The script leaves some tasks up to the administrator. I didn't include these tasks in the script for a few reasons. Some things I prefer doing by hand, while other things I was just too lazy to script. The following tasks should be completed after running the script:

1. Changing the password for $REGULARUSER
2. Adding $REGULARUSER to the sudoers file
3. Changing the mysql root password
4. Adding certificates to the /etc/nginx/certs directory (or whever your certificate directory is in the restored nginx configs)
5. Configuring SSH as desired - disabling root access, adding $REGULARUSER, adding SSH keys, etc.

It is also recommended that the server be rebooted after running the script and completing any additional administrative tasks.



