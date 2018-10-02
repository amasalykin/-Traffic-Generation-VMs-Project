#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name: 
# Date: August 5, 2018
#
# This script will guide you through the process to set DHCP for the IP address
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# Save the name of the second network connection as the variable connect_name

    connect_name="Equipment"

# The warning message about the script

    echo -e "-- \e[31mAttention! \e[0m--"
    echo "This script will set DHCP for the network adapter named $connect_name"
    echo "To terminate the script press Ctrl-C"
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
    
# IP address for the NIC   
 
    ip="$(nmcli con sh id $connect_name | grep IP4.ADDRESS | awk '{print $2}')"

# Define the device name according to the alias of the second network connection
   
   device="$(nmcli con sh id $connect_name | grep GENERAL.DEVICES | awk '{print $2}')"
    
 # Set DHCP for the second network connection

    nmcli con mod $connect_name ipv4.method auto

# Delete the IP adress and DNS record from the second network adapter

    nmcli con mod $connect_name -ipv4.address $ip

# Calculate the network address according to the IP from the user

    network="$(ipcalc -n $(nmcli con sh id $connect_name | grep IP4.ADDRESS | awk '{print $2}') | cut -d= -f2)"
    
# Take the last octet the network address

    last_net_oct="$(echo "$network" | cut -d'.' -f 4)"

# Increment the last octet by 1

    last_net_octet_inc="$(($last_net_oct +1))"

# The first IP from the network. Take first three octets from the network ipcalc and concatenate with "." and the last octet

    first_IP="$(echo "$network" | cut -d'.' -f 1-3 )$(echo ".")$last_net_octet_inc"

# Delete the static route to the second network adapter

    nmcli con mod $connect_name -ipv4.routes "172.16.0.0/12 $first_IP"

# Set auto routes and default routes for the second connection as default

    nmcli con mod $connect_name ipv4.ignore-auto-routes no
    nmcli con mod $connect_name ipv4.never-default no

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

# The IP reset complete
    
    echo ""
    echo "Complete!"
    
exit 0
