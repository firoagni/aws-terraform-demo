#!/bin/bash
sudo yum -y update
sudo yum install -y httpd
sudo chmod 777 /var/www/html
echo Application Server is up and Running >> /var/www/html/index.html
sudo service httpd start
sudo chkconfig httpd on
sudo service httpd status


