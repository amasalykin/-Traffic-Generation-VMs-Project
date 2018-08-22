#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name: Shoaib Qureshi
# Date: August 5, 2018
#
# This script will guide you through disabling Apache and all support services on the host and removing the files
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# Warning message about the script

    echo -e "-- \e[31mAttention! \e[0m--"
    echo "This script will disable the Apache server and clear all files"
    echo "that were set for Apache by the webconf.sh script."
    echo "The firewall rules for Apache will be disabled as well."
    echo "To terminate the script press Ctrl-C"
    echo ""
    printf "Press [Enter] to continue."
    read -r

# Stop and disable HTTP service

 	systemctl stop httpd
	systemctl disable httpd

# Remove all of the created physical directories from /var/www/ and only leave default directories /html and /cgi-bin
	
	cd /var/www/
	shopt -s extglob
	rm -rf !(html|cgi-bin)
	
# Delete Virtual Host Directories

	rm -rf /etc/httpd/sites-available
	rm -rf /etc/httpd/sites-enabled

# Remove all added lines from the main Apache configuration file /etc/httpd/conf/httpd.conf and leave the default lines (353) only

	head -n 353 /etc/httpd/conf/httpd.conf > temp &&  mv -f temp /etc/httpd/conf/httpd.conf

# Remove the HTTP firewall rules for Apache

	echo ""
    echo "Remove the HTTP firewall rules for Apache"
    if ! firewall-cmd --remove-service=http --permanent # if HTTP service has not been removed
    then
		echo ""
        echo -e "\e[31mThe HTTP firewall rules have not been removed.\e[0m"
        exit 1
    fi
    
    if ! firewall-cmd --reload # if unable to reload firewall rules
    then
		echo ""
        echo -e "\e[31mThe firewall has failed to reload.\e[0m"
        exit 1
    fi

# The Apache configuration has been cleaned from the host

    echo ""
    echo "Complete!"
    
exit 0