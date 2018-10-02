#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name:  
# Date: August 5, 2018
#
# This script will install standard packages for the template and set the aliases for the network connections.
# The script will check the kernel version of the CentOS 7 and will be able to delete
# the old kernel version according to the user's response.
#
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# The information message about the script for the user

    echo -e "\e[32mThis script will install packages for the template"
    echo -e "and set the aliases as Production and Equipment for the network connections.\e[0m"
	echo "To abort the script press Ctrl-C."
    echo ""
    printf "Press [Enter] to continue."
    read -r    

# Changing the name of the network interfaces the first interface (NR == 1) and the second interface (NR == 2)
# Setting both interfaces to the DHCP.

	nmcli connection modify "$(ip a | grep -o 'ens.*' | cut -d: -f1 | uniq | awk 'NR == 1')" connection.id Production 
	nmcli con modify Production connection.autoconnect yes
	nmcli con modify Production ipv4.method auto
	nmcli connection up Production

	nmcli connection modify "$(ip a | grep -o 'ens.*' | cut -d: -f1 | uniq | awk 'NR == 2')" connection.id Equipment
	nmcli con modify Equipment connection.autoconnect yes
	nmcli con modify Equipment ipv4.method auto
	nmcli connection up Equipment 

# Checking the names of the network devices
	
	echo ""
	echo -e "\e[35mCheck the names of the network devices.\e[0m"
	echo ""
	nmcli connection show
	echo ""
	printf "Press [Enter] to continue."
	read -r

# Installing yum-utils

	yum -y install yum-utils 

# Ensuring that the current version is the most recent one and delete the previous kernel version

	echo ""
	echo -e "\e[35mEnsure that the current version of the kernel core is the most recent one.\e[0m"	
	
# Checking the installed Linux kernels

	echo ""
	echo "Installed Linux kernels:"	
	rpm -qa kernel

# Checking the version of the current kernel core

	echo ""
	echo "The current version of the kernel core:"	
	uname -sr

	echo ""
	printf "Press [Enter] to continue."
	read -r

# Asking user to delete the previous version of the kernel

	echo ""
	echo -e "\e[35mDo you want to delete the old version of the kernel?\e[0m"	
	read -p 'Please, enter y or n: ' 	response

# Checking the user answer

	while true ; do
		if [[ "$response" == [Yy]* ]] || [[ "$response" == [Nn]* ]]; then
			break
		else
			echo ""
    		echo "Sorry. You have entered the wrong answer."            
			read -p 'Please, enter y or n: ' 	response
		fi
	done

	if [[ "$response" == [Yy]* ]]; then
		    package-cleanup -y --oldkernels --count=1
			echo ""
		    echo -e "\e[35mThe old version of the kernel has been deleted successfully.\e[0m"
			printf "Press [Enter] to continue."
			read -r
			echo ""
	fi    

# Installing Apache web service

	yum -y install httpd 

# Installing BIND DNS service and utilities

	yum -y install bind bind-utils 

# Installing networking tools with ifconfig command

	yum -y install net-tools 

# Installing Lynx text browser

	yum -y install lynx
	
# Installing Bash completion

	yum -y install bash-completion bash-completion-extras

# The script is completed

    echo "The build configuration is completed!"
    
exit 0
