#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name: 
# Date: August 5, 2018
#
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# Save the name of the second network connection as the variable connect_name

    connect_name="Equipment"

# The information message about the script for the user

    echo ""
    echo -e "\e[32mThis script will help to set up the IP address for the network adapter named $connect_name\e[0m"
    echo "To terminate the script press Ctrl-C"
	echo "To Reset configuration of the $connect_name adapter to DHCP run ip_reset.sh"
    echo ""    
    printf "Press [Enter] to continue."
    read -r

# Check the existence of the connection name Equipment

        while [[ -z "$connect_name" || "$connect_name" != "$(nmcli con sh | awk 'FNR>1 {print $1}' | grep -w "$connect_name")" ]] ; do
            echo ""
            echo -e "\e[32mSorry. The connection name $connect_name does not exist.\e[0m"
            echo ""
            echo "The connection name should be one from the list:"
            nmcli con sh | awk '//{printf "\033[32m%-10s %s\n\033[0m",$1,$4}'
            echo ""
            echo "Please, enter the connection name or press Ctrl-C to exit" 
            read -p 'The connection name: ' connect_name
        done

        echo ""
        echo -e "The connection name is \e[35m$connect_name\e[0m"
    
# Ask user to enter the IP address for the second network adapter
    
    echo""
    echo "Enter the IP address in 172.x.x.x/X format"
    echo "The second octet of the IP address should be in the range 16-31"
    read -p 'IP address: '      ip_addr_CIDR

# Check that the IP address is the correct format 172.x.x.x/X

# Set boolean variable k to false (0)

    k=0

    while [[ $k -ne 1 ]]; do

        if expr "$ip_addr_CIDR" : '[1][7][2]\.[1-3][0-9]\.[0-9]*\.[0-9]*\/[0-9][0-9]$' >/dev/null; then

        ip_addr="$(echo "$ip_addr_CIDR" | cut -d"/" -f1)" 

        for i in 1 2 3 4 5; do
            if  [ $i -eq 2 ] && ( [ $(echo "$ip_addr" | cut -d. -f$i) -lt 16 ] || [ $(echo "$ip_addr" | cut -d. -f$i) -gt 31 ] ) ; then
                echo "fail ($ip_addr_CIDR)"
                echo "The second octet of the IP address should be in the range 16-31"
                read -p 'IP address: '  ip_addr_CIDR
                let k=0
                break
            elif [ $i -eq 5 ] && ( [ $(echo "$ip_addr_CIDR" | cut -d"/" -f2) -lt 0 ] || [ $(echo "$ip_addr_CIDR" | cut -d"/" -f2) -gt 32 ] ); then 
                echo "fail CIDR"
                echo "The CIDR Notation should be between 0 and 32"
                read -p 'IP address: '  ip_addr_CIDR
                let k=0
                break             
            elif [ $i -le 4 ] && [ $(echo "$ip_addr" | cut -d. -f$i) -gt 255 ] ; then
                echo "fail ($ip_addr_CIDR)"
                echo "The IP address octets cannot be more then 255"
                read -p 'IP address: '  ip_addr_CIDR
                let k=0
                break                                                
            elif [ $i -le 4 ] && [ $(echo "$ip_addr" | cut -d. -f$i) -le 255 ]; then                                                
                let k=1
                continue
                                                                                               
            fi
        done

        else
            echo "fail ($ip_addr_CIDR)"
            echo "Enter the IP address in the following format: 172.x.x.x/X"
            echo "The second octet of the IP address should be in the range 16-31"
        read -p 'IP address: '  ip_addr_CIDR
        fi
        done
        
        echo ""
        echo -e "The IP address for the second network connection $connect_name: \e[35m$ip_addr_CIDR\e[0m"

# Set the second network adapter to manual IPv4

    nmcli con mod $connect_name ipv4.address $ip_addr_CIDR  
    nmcli con mod $connect_name ipv4.method manual

# Ignore auto routes and default routes for the second connection

    nmcli con mod $connect_name ipv4.ignore-auto-routes yes
    nmcli con mod $connect_name ipv4.never-default yes

# Calculate the network address according to the IP from the user

    network="$(ipcalc -n $ip_addr_CIDR | cut -d'=' -f 2)"
    echo ""
    echo -e "IP of the network is \e[35m$network\e[0m"
    
# Take the last octet the network address

    last_net_oct="$(echo "$network" | cut -d'.' -f 4)"

# Increment the last octet by 1

    last_net_octet_inc="$(($last_net_oct +1))"

# The first IP of the network. Take the first three octets from the network ipcalc and concatenate with "." and the last octet

    first_IP="$(echo "$network" | cut -d'.' -f 1-3 )$(echo ".")$last_net_octet_inc"

# Set default gateway to the first valid IP address for the second network connection         
# ! Depends on the requirements for auto routes and the default route !
# If parameters ipv4.ignore-auto-routes and ipv4.never-default set as "yes" then this part of the code will stay commented out
#    echo ""
#    echo -e "The default gateway IP is \e[35m$first_IP\e[0m"
#    nmcli con mod $connect_name ipv4.gateway $first_IP

# Define the device name according to the alias of the second network connection
   
   device="$(nmcli con sh id $connect_name | grep GENERAL.DEVICES | awk '{print $2}')"

# Add static route for networks 172.16.0.0/16 through 172.31.0.0/16

    echo ""
    echo "Set the ip route 172.16.0.0/12 via $first_IP"
    nmcli con mod $connect_name ipv4.routes "172.16.0.0/12 $first_IP"

# Bring the connection up 

    nmcli connection up $connect_name

# Restart network manager service
    
    echo "Restart the network service"
    if ! systemctl restart network # if service has failed
    then
        echo ""
        echo -e "\e[31mThe network service has failed to restart\e[0m"
        exit 1
    fi

# The configuration has completed
   
    echo ""
    echo "Complete!"
exit 0
