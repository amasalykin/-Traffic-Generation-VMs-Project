#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name:  
# Date: August 5, 2018
#
# This script will guide you through disabling BIND and all support services on the host and removing the files.
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# The information message about the script for the user

    echo -e "-- \e[31mAttention! \e[0m--"
    echo "This script will disable the BIND server and clear all files"
    echo "that were created for the BIND by the dnsconf.sh script."
    echo "The firewall rules for DNS will be disabled as well."
	echo "To abort the script press Ctrl-C"
    echo ""
    printf "Press [Enter] to continue."
    read -r
    
# Removing the files that BIND uses for forward and reverse zones' description

    rm -f /etc/named/named.conf.local

# Removing the zone directories for BIND

    rm -rf /etc/named/zones

# Setting the default settings for the named.conf file

cat > /etc/named.conf <<EOF
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

options {
	listen-on port 53 { 127.0.0.1; };
	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	allow-query     { localhost; };

	/* 
	 - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
	 - If you are building a RECURSIVE (caching) DNS server, you need to enable 
	   recursion. 
	 - If your recursive DNS server has a public IP address, you MUST enable access 
	   control to limit queries to your legitimate users. Failing to do so will
	   cause your server to become part of large scale DNS amplification 
	   attacks. Implementing BCP38 within your network would greatly
	   reduce such attack surface 
	*/
	recursion yes;

	dnssec-enable yes;
	dnssec-validation yes;

	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.iscdlv.key";

	managed-keys-directory "/var/named/dynamic";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
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
EOF

# Stopping DNS BIND service daemon

    systemctl stop named
    systemctl disable named
    chkconfig named off

# Removing the firewall rules for DNS
    
    echo ""
    echo "Removing the firewall rules for DNS."
    if ! firewall-cmd --remove-service=dns --permanent # if the dns rule has not been removed
    then
        echo ""
        echo -e "\e[31mThe firewall rules have not been removed.\e[0m"
        exit 1
    fi
    
    if ! firewall-cmd --reload # if the firewall has failed to reload
    then
        echo ""
        echo -e "\e[31mThe firewall has failed to reload.\e[0m"
        exit 1
    fi

# The BIND configuration has been cleaned for the host

    echo ""
    echo "Complete!"
    
exit 0
