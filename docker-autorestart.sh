#!/bin/bash
#
# Run this script evey 10 min:
# crontab -e
# */10 * * * * /home/media/docker-media/docker-autorestart.sh

FILE_PATH=$(readlink -f $(dirname $0))  #/home/media/docker-media
FILE_NAME=$(basename $0)                #docker-autorestart.sh
FILE_NAME=${FILE_NAME%.*}               #docker-autorestart
FILE_DATE=$(date +'%Y%m%d-%H%M%S')
FILE_LOG="/var/log/$FILE_NAME.log"

if [ $(docker container ls -f status=exited | sed '1 d' | wc -l) -gt 0 ]; then
  # Source .env file
  cd $FILE_PATH
  . .env > /dev/null 2>&1

  runstart=$(date +%s)
  echo "* Command: $0 $@" | tee -a $FILE_MAIL
  echo "* Start time: $(date)"
  echo "* "

  echo "* "
  echo "* Environment Variables:"
  echo "* HOST_IP = $HOST_IP"
  echo "* HOST    = $HOST"
  echo "* DOMAIN  = $DOMAIN"

  # Kill ports used for Traefik service
  sudo fuser --kill 80/tcp > /dev/null 2>&1
  sudo fuser --kill 443/tcp > /dev/null 2>&1

  echo "* "
  echo "* Restart suspended docker services..."
  docker container ls -f status=exited | sed '1 d' | awk '{print $2}'
  docker restart $(docker container ls -f status=exited | sed '1 d' | awk '{print $1}') > /dev/null

  echo "* "
  echo "* End time: $(date)"
  runend=$(date +%s)
  runtime=$((runend-runstart))
  echo "* Elapsed time: $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
fi

# docker logs traefik
# time="2021-06-04T10:35:23+02:00" level=error msg="accept tcp [::]:80: use of closed network connection" entryPointName=web
if [ $(docker logs traefik 2> /dev/null | grep "$(date +'%Y-%m-%dT%H:')" | grep "level=error" | grep "use of closed network connection" | wc -l) -gt 0 ]; then
  runstart=$(date +%s)
  echo "* Command: $0 $@" | tee -a $FILE_MAIL
  echo "* Start time: $(date)"
  echo "* "

  # Kill ports used for Traefik service
  sudo fuser --kill 80/tcp > /dev/null 2>&1
  sudo fuser --kill 443/tcp > /dev/null 2>&1
  sudo fuser --kill 8080/tcp > /dev/null 2>&1
  
  echo "* Recreate docker services..."
  #docker restart $(docker container ls | sed '1 d' | awk '{print $1}') > /dev/null
  cd $FILE_PATH
  docker-compose up -d --no-deps --force-recreate

  echo "* "
  echo "* Restart linked services..."
  sudo systemctl restart vboxdrv && systemctl restart vboxweb-service && systemctl restart vboxweb-service
    sleep 2
  sudo systemctl restart kodi

  echo "* "
  echo "* End time: $(date)"
  runend=$(date +%s)
  runtime=$((runend-runstart))
  echo "* Elapsed time: $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
fi


exit 0
