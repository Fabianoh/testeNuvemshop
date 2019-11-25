#!/bin/bash
yum update -y
yum install -y httpd
echo 'Ola pessoal da NuvemShop!!!' > /var/www/html/index.html
service httpd start
