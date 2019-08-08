#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'Please pass environment name'
    exit 1
fi

## CONST
scriptDir=$(pwd)
randNumber="$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 5)"
gitUsername="anandemdb"
gitPassword="Angelvyas1!"

branch="$1" #github branch
appname="$2" #domain name
country=${appname##*.}

currentTime=$(date +"%s")

## Remove docker running images
command="docker kill $(docker ps -a --format '{{.Names}}' | grep -G "^$appname")"
$command
command="docker rm $(docker ps -a --format '{{.Names}}' | grep -G "^$appname")"
$command

## Remove current existed folders
command="sudo rm -rf /var/www/html/$appname*"
$command

## Remove file
command="sudo rm /etc/nginx/sites-enabled/$appname"
$command
command="sudo rm /etc/nginx/sites-available/$appname"
$command

## change directory
command="cd /var/www/html"
$command

## Current Dir
currentDir=$(pwd)

#country="us"
## pull front code from server
repo=$([ "$country" == "us" ] && echo "tl-front" || echo "tl-india-front")
frontGitUrl="https://$gitUsername:$gitPassword@github.com/Trustlogics/$repo.git"
command="git clone -b $branch $frontGitUrl $appname"
$command

## pull backend code from server
repo=$([ "$country" == "us" ] && echo "tl-api" || echo "tl-india-api")
apiGitUrl="https://$gitUsername:$gitPassword@github.com/Trustlogics/$repo.git"
command="git clone -b $branch $apiGitUrl $appname/rest"
$command

## Add new folder in rest folder
cd $currentDir
mkdir -p  $currentDir/$appname/rest/uploads/captcha
mkdir -p  $currentDir/$appname/rest/uploads/badges
mkdir -p  $currentDir/$appname/rest/uploads/jobseeker/resumes
mkdir -p  $currentDir/$appname/rest/uploads/qrcode/companyprofile
mkdir -p  $currentDir/$appname/rest/uploads/qrcode/joblisting
mkdir -p  $currentDir/$appname/rest/uploads/qrcode/recruiter
mkdir -p  $currentDir/$appname/rest/uploads/rpoadmin/invitations
mkdir -p  $currentDir/$appname/rest/application/logs

# Change robots and sitemap.xml file
echo -e "User-agent: * \nDisallow: /" > $currentDir/$appname/robots.txt
echo "" > $currentDir/$appname/sitemap.xml

#/uploads/badges
#/uploads/avatar/
#/uploads/company_logo/
#/uploads/jobseekerwork/

## PHP info
echo "<?php phpinfo(); ?>" > $currentDir/$appname/info.php

## make public access dir
command="sudo chmod -R 777 $currentDir/$appname/rest/uploads"
$command

## Copy .env files
#frontEnvFile="$scriptDir/$1-front-env.env"
#apiEvnFile="$scriptDir/$1-api-env.env"

#if [ ! -f $frontEnvFile ]; then
#frontEnvFile="$scriptDir/dev-front-env.env"
#fi

#if [ ! -f $apiEvnFile ]; then
#apiEvnFile="$scriptDir/dev-api-env.env"
#fi

frontEnvFile="$currentDir/$appname/environment/$1/front.env"
apiEvnFile="$currentDir/$appname/environment/$1/api.env"

cp $frontEnvFile $currentDir/$appname/.env
cp $apiEvnFile $currentDir/$appname/rest/.env

## Change the version of the application
command="sed -i "/VERSION/c\VERSION="1.0.$currentTime"" $currentDir/$appname/.env"
$command

## Create docker images on dynamic port
command="docker run -itd --name $appname -p 80 -v $currentDir/$appname:/var/www/html anandvyas786/php:7.0"
$command


dockerExposePort="$(docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' $appname)"
echo "server {
        listen 80;
        listen [::]:80;

	#hide the nginx server information
        server_tokens off;

	#redirect error page
	error_page 401 403 404 /error;

	index  index.php index.html index.htm;

        server_name $appname;

	client_max_body_size 100M;

        location / {
            proxy_pass http://localhost:$dockerExposePort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
	    proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

	    proxy_read_timeout          300;
        }

	error_log $currentDir/$appname/error.log;
	access_log $currentDir/$appname/access.log;

	location ~ /\. {
                deny all;
        }


}" |  sudo tee -a /etc/nginx/sites-available/$appname

command="sudo ln -s /etc/nginx/sites-available/$appname /etc/nginx/sites-enabled/"
$command

command="sudo systemctl reload  nginx"
$command