#!/bin/bash
yum update -y
sudo yum install nginx -y
sudo amazon-linux-extras install nginx1.12 -y
sudo cp /usr/share/nginx/html/index.html /usr/share/nginx/html/nginx.html
sudo service nginx start

