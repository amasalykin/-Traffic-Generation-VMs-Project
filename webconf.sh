#!/bin/bash
#
# Copyright (c) 2018 Conestoga College,
# Name: 
# Date: August 5, 2018
#
# This script will allow the user to configure the Apache web service
# This script will bootstrap these OSes:
#   - CentOS 7
#   - RHEL 7

# Network alias name for the connection

    connect_name="Equipment"

# The message to the user providing information about the script

    echo -e "-- \e[31mAttention! \e[0m--"
    echo "This script will turn a fresh host into an Apache server."
    echo -e "This script will use the network adapter named \e[35m$connect_name\e[0m"
    echo "To terminate the script press Ctrl-C"
    echo ""    
    printf "Press [Enter] to continue."
    read -r

# Checking the existence of the connection named Equipment

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

# IP address for the network adapter

    ip="$(nmcli con sh id $connect_name | grep IP4.ADDRESS | awk '{print $2}' | cut -d/ -f1)"

# Hostname

	hostname=$(hostname -s)

# Start and enable HTTPD service
  
	echo ""
	echo "Enable and start the httpd service."
	echo "Start of the httpd service can take some time."
    systemctl enable httpd
    systemctl start httpd
	
# Accept a domain name as an argument - domain_name
  
	echo""
	echo "Enter the domain name."
	echo "The domain name should be internet.local or intranet.local"
	read -p 'Domain name: '	domain_name

# The following steps will Configure apache to respond to either www.internet.local or www.intranet.local, 
# only on the network adapter

# Check that the domain name is internet.local or intranet.local

    while [ "$domain_name" != "internet.local" ] && [ "$domain_name" != "intranet.local" ]; do
    echo ""
	echo "Sorry. You have entered the wrong domain name"
    echo "The domain name should be internet.local or intranet.local"
	read -p 'Domain name: '	domain_name
	done

	echo""
	echo -e "The domain name is \e[35m$domain_name\e[0m"	

# Create a physical directory structure for the virtual host using $domain_name, that will hold data

	mkdir -p /var/www/$domain_name/public_html
	
# Give the regular user permissions to modify files in web directories

	chown -R $USER:$USER /var/www/$domain_name/public_html
	
# Modify the permissions of the general web directory and whatever it contains, to allow
# read access, enabling the web server to serve content to users

	chmod -R 755 /var/www

# Create a HTML welcome page file for each virtual host

	touch /var/www/$domain_name/public_html/index.html

# Inside the index.html file, place content for both virtual host sites

cat > /var/www/$domain_name/public_html/index.html << EOF
	<html>
  		<head>
    		<title>Welcome to $domain_name!</title>
  		</head>
  		<body>
    		<h1>Success! Welcome to $domain_name site!</h1>
  		</body>
	</html>
EOF
	
# Create Directories where Virtual Hosts will be stored
	
	mkdir /etc/httpd/sites-available # The directory where per-site "Virtual Hosts" can be stored
	mkdir /etc/httpd/sites-enabled	 # The directory where enabled per-site "Virtual Hosts" are stored
	
# Tell Apache to look for the created virtual hosts directory and additional server name 
# by editing the Apache main configuration file  

	echo "IncludeOptional sites-enabled/*.conf" >> /etc/httpd/conf/httpd.conf
	echo "ServerName www.$domain_name:80" >> /etc/httpd/conf/httpd.conf

# Create a Virtual Host configuration file
	
	touch /etc/httpd/sites-available/$domain_name.conf

# Content inside Virtual Host configuration file

cat > /etc/httpd/sites-available/$domain_name.conf << EOF
Listen 0.0.0.0:80

	<VirtualHost   $ip:80>
		ServerName $hostname.$domain_name
		DocumentRoot /var/www/$domain_name/public_html
		ErrorLog /var/log/httpd/error_log
		CustomLog /var/log/httpd/access_log combined
	</VirtualHost>
EOF

# Enable the New Virtual host files using a symbolic link to the "sites-enabled" folder

	ln -s /etc/httpd/sites-available/$domain_name.conf /etc/httpd/sites-enabled/$domain_name.conf
	
# Restart HTTPD services to make configuration changes effective	

	systemctl restart httpd

# Add the firewall rules to allow HTTP service
  
  	echo ""
    echo "Add the HTTP firewall rules for Apache"
	if ! firewall-cmd --add-service=http --permanent # if HTTP service has not been added
    then
    	echo ""
        echo -e "\e[31mThe HTTP firewall rules have failed to be added.\e[0m"
        exit 1
    fi
    
    if ! firewall-cmd --reload # if unable reload the firewall rules
    then
    	echo ""
        echo -e "\e[31mThe firewall has failed to reload.\e[0m"
        exit 1
    fi    
 
# Check the Apache configuration by running a test

    echo ""
    echo "Check the validity of the configuration files in the Apache server"  
    apachectl configtest
  
# This host is now running Apache web services

    echo ""
    echo "Complete!"
    
exit 0
