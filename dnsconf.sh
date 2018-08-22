#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name: Andrey Masalykin 
# Date: August 5, 2018
#
# This script will guide you through setting up BIND on the host and making the changes needed.
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# Network alias name for the connection

    connect_name="Equipment"

# The information message about the script for the user

    echo -e "-- \e[31mAttention! \e[0m--"
    echo "This script will turn a fresh host into a BIND server and walk you through changing DNS"
    echo "settings. If you have previously run this script on this host, or another host"
    echo "within the same virtual network: "
    echo "stop running this script and run the reset DNS script dns_reset.sh before continuing."
    echo -e "This script will use the network adapter named \e[35m$connect_name\e[0m"
    echo "To abort the script press Ctrl-C"
    echo ""    
    printf "Press [Enter] to continue."
    read -r

# Checking the existence of the connection name Equipment

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

# IP address of the network adapter

    ip="$(nmcli con sh id $connect_name | grep IP4.ADDRESS | awk '{print $2}' | cut -d/ -f1)"

# Pointer record prefix for reverse lookup zone

	ptr_record_prefix="$(echo "$ip" | awk -F. '{print $3"." $2"."$1}')"

# Hostname for DNS records

	hostname=$(hostname -s)

# Hostnumber for reverse lookup zone

	hostnumber=$(echo "$ip" | cut -d . -f 4)

# Semicolon variable for the ip_forwarder address in the named.conf file

    semicolon=""

# Creating the directories that will be used by BIND service

    mkdir /etc/named/zones

# Creating the files that will be used by BIND for forward and reverse zones

    touch /etc/named/named.conf.local
    touch /etc/named/zones/db.forward
    touch /etc/named/zones/db.reverse

# Starting DNS BIND service daemon and restart in the case that the service has been enabled

    echo "Start the DNS service."
    systemctl enable named
    systemctl start named

# Accepting a domain name as the argument domain_name
 
    echo ""
	echo "Enter the domain name."    
	echo "The domain name should be the internet.local or intranet.local"	
	read -p 'Domain name: '	domain_name

# Checking that the domain name is either internet.local or intranet.local

    while [ "$domain_name" != "internet.local" ] && [ "$domain_name" != "intranet.local" ]; do
    echo "Sorry. You have entered the wrong domain name."
    echo ""
    echo "The domain name should be internet.local or intranet.local"
	read -p 'Domain name: '	domain_name
	done
	echo ""
	echo "The domain name is $domain_name"

# Asking the user about the IP address for another DNS (forwarder)
	
	echo ""
	echo "Do you want to enter an IP address for a DNS forwarder?"	
	read -p 'Please, enter y or n: ' 	response

# Checking the user response

	while true ; do
		if [[ "$response" == [Yy]* ]] || [[ "$response" == [Nn]* ]]; then
			break
		else
			echo ""
            echo "Sorry. You have entered the wrong answer."            
			read -p 'Please, enter y or n: ' 	response
		fi
	done

# Asking the user to enter the IP address for the DNS forwarder 

	if [[ "$response" == [Yy]* ]]; then
		    echo ""
		    echo "Enter the IP address for the DNS forwarder in x.x.x.x format."		    
		    read -p 'IP address: '	ip_forwarder    

# Checking that the IP address is the correct format x.x.x.x and valid

		k=0 # Boolean true (1) false (0)

        while [[ $k -ne 1 ]]; do

            if expr "$ip_forwarder" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then

                for i in 1 2 3 4; do
                     if [ $(echo "$ip_forwarder" | cut -d. -f$i) -gt 255 ]  ; then
                        echo "fail ($ip_forwarder)"
                        echo ""
                        echo "The IP address octets cannot be more than 255."                                                
                        read -p 'IP address: '  ip_forwarder
                        let k=0
                        break                                                
                    elif [ $(echo "$ip_forwarder" | cut -d. -f$i) -le 255 ]; then
                        let k=1 # Set the boolean to true (1)
                        continue
                    fi
                done

            else
                echo "fail ($ip_forwarder)"
                echo ""
                echo "Enter the IP address for the DNS forwarder in x.x.x.x format."                       
                read -p 'IP address: '  ip_forwarder
            fi
        done
                
                semicolon=";"
                
                echo ""
                echo -e "IP address for the DNS forwarder: \e[35m$ip_forwarder\e[0m"                
    fi
               	echo ""
                echo -e "The IP of the network adapter $connect_name: \e[35m$ip\e[0m"
                echo ""
                echo -e "Domain name: \e[35m$domain_name\e[0m"
                echo ""
                echo -e "Pointer record prefix: \e[35m$ptr_record_prefix\e[0m"
                echo ""

# Writing the BIND files

# The configuration of the named.conf file according to the user's responses

cat > /etc/named.conf <<EOF
acl trusted {
    ${ip};
};

options {
    listen-on port 53 { 127.0.0.1; ${ip}; };
    listen-on-v6 port 53 { ::1; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query { localhost; trusted; };
    recursion yes;
    allow-recursion { localhost; trusted; };
    forwarders { ${ip_forwarder}${semicolon} };
    dnssec-enable no;
    dnssec-validation no;
    dnssec-lookaside auto;

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.iscdlv.key";

    managed-keys-directory "/var/named/dynamic";
};


logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};


zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/named/named.conf.local"; /* Forward and Reverse Zones */
EOF

# Zone files

cat > /etc/named/named.conf.local <<EOF
zone "${domain_name}" IN {
    type master;
    file "/etc/named/zones/db.forward";
    allow-update { ${ip}; };
};

zone "${ptr_record_prefix}.in-addr.arpa" IN {
    type master;
    file "/etc/named/zones/db.reverse";
    allow-update { ${ip}; };
 };
EOF

# Forward zone

cat > /etc/named/zones/db.forward <<EOF
\$TTL    604800
@       IN      SOA     ${hostname}.${domain_name}. hostmaster.${domain_name}.(
        2018062601     ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
; Name Server Information
@           IN  NS      ${hostname}.${domain_name}.
; Mail exchanger
                    IN  MX 10    ${hostname}
; A - Record HostName to the IP address
${hostname}        IN  A 			 ${ip}
${domain_name}.    IN  A 			 ${ip}
; www Alias record
www                IN  CNAME	 	${hostname}
EOF

# Reverse zone

cat > /etc/named/zones/db.reverse <<EOF
\$TTL 	604800
@   	IN  SOA     ${hostname}.${domain_name}. hostmaster.${hostname}.${domain_name}. (
        2018062601     ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
; Name Server Information
@					IN  NS      ${hostname}.${domain_name}.
; Reverse lookup for Name Server
${hostnumber}				IN  PTR    ${hostname}.${domain_name}.
EOF

# Checking BIND Configuration Syntax

    chown -R named:named /etc/named*
    if ! named-checkconf /etc/named.conf # if named-checkconf check has failed
    then
    	echo ""
        echo -e "\e[31mThe configuration of the file /etc/named.conf has failed.\e[0m"
        exit 1
    fi
    if ! named-checkzone "${domain_name}" /etc/named/zones/db.forward # if check for forward zone has failed
    then
    	echo ""
        echo -e "\e[31mThe configuration of the file /etc/named/zones/db.forward has failed.\e[0m"
        exit 1
    fi
    if ! named-checkzone "${ptr_record_prefix}.in-addr.arpa" /etc/named/zones/db.reverse # if check for reverse zone has failed
    then
    	echo ""
        echo -e "\e[31mThe configuration of the file /etc/named/zones/db.reverse has failed.\e[0m"
        exit 1
    fi
   
# Restarting the DNS service  

    systemctl restart named

# Ensure named service is set to run at startup 
	
	echo ""
    echo "Assuring that DNS is set to run at startup."
    chkconfig named on    

# Adding the firewall rules for DNS

    echo ""
    echo "Adding the firewall rules for DNS."
    if ! firewall-cmd --add-service=dns --permanent # if the dns rule has not been added
    then
    	echo ""
        echo -e "\e[31mThe firewall rules have not been added.\e[0m"
        exit 1
    fi
    
    if ! firewall-cmd --reload # if the firewall has failed to reload
    then
    	echo ""
        echo -e "\e[31mThe firewall has failed to reload.\e[0m"
        exit 1
    fi    

# This host is now running BIND
   
    echo ""
    echo "Complete!"

exit 0