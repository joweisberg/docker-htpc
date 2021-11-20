#!/bin/bash

FILE_PATH=$(readlink -f $(dirname $0))  #/home/media/docker-media
FILE_NAME=$(basename $0)                #docker-build.sh
FILE_NAME=${FILE_NAME%.*}               #docker-build
FILE_DATE=$(date +'%Y%m%d-%H%M%S')
FILE_LOG="/var/log/$FILE_NAME.log"

HOST=$(hostname -A | awk '{ print $1 }')
HOST_IP=$(hostname -I | awk '{ print $1 }')

# Force sudo prompt at the begining
sudo echo > /dev/null

sudo systemctl stop vboxweb-service
sudo sed -i "s/^VBOXWEB_HOST=.*/VBOXWEB_HOST=$HOST_IP/" /etc/default/virtualbox


#if [ $(docker images local/certs-extraction | wc -l) -ne 2 ]; then
#  echo "* Build image: local/certs-extraction"
#  cd ~/docker-certs-extraction/
#  docker build -t local/certs-extraction .
#fi
#if [ $(docker images local/jq | wc -l) -ne 2 ]; then
#  echo "* Build image: local/jq"
#  cd ~/docker-jq/
#  docker build -t local/jq .
#fi
#if [ $(docker images local/glances | wc -l) -ne 2 ]; then
#  echo "* Build image: local/glances"
#  cd ~/docker-glances/
#  docker build -t local/glances .
#fi
#if [ $(docker images local/phpvirtualbox | wc -l) -ne 2 ]; then
#  echo "* Build image: local/phpvirtualbox"
#  #git clone https://github.com/phpvirtualbox/phpvirtualbox.git
#  cd ~/docker-phpvirtualbox/
#  git fetch --all && git reset --hard && git checkout
#  sed -i "s/github.com\/phpvirtualbox\/phpvirtualbox\/archive\/.*/github.com\/phpvirtualbox\/phpvirtualbox\/archive\/develop.zip -O phpvirtualbox.zip \\\/g" Dockerfile
#  docker build -t local/phpvirtualbox .
#fi

# Overwrite host, ip and domain name on environment file
cd $FILE_PATH
sed -i "s/^HOST=.*/HOST=$HOST/" .env
sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" .env
. .env > /dev/null 2>&1
sed -i "s/^OWNCLOUD_DOMAIN=.*/OWNCLOUD_DOMAIN=$DOMAIN/" .env
# Source .env file
. .env > /dev/null 2>&1

# Update docker variables
#sed -i "s/^    main = \".*/    main = \"$DOMAIN\"/" /var/docker/traefik/traefik.toml
sed -i "s/htpc.ejw/$HOST/g" /var/docker/traefik/servers.toml

echo "* "
echo "* Environment Variables:"
echo "* HOST_IP = $HOST_IP"
echo "* HOST    = $HOST"
echo "* DOMAIN  = $DOMAIN"

echo "* "
echo "* Stop docker services"
docker-compose down
if [ $(docker ps -a -q | wc -l) -gt 0 ]; then
  echo "* "
  echo "* Force to stop docker services"
  docker stop $(docker ps -a -q)
  echo "* "
  echo "* Force to remove docker volumes"
  docker rm --volumes --force $(docker ps -a -q)
fi
NETWEB="web"
NETLAN="macvlan0"
ETH=$(ip -o -4 route show to default | awk '{print $5}')                              # eno1
IPADDR_GTW=$(ip -o -4 route show to default | awk '{print $3}')                       # 192.168.1.1
IPADDR=$(ip -o -4 route show dev $ETH | grep '^default' | awk '{print $7}')           # 192.168.1.10
IPADDR=$HOST_IP                                                                       # 192.168.1.10
NETADDR=${IPADDR%.*}                                                                  # 192.168.10
sed -i "s/^ETH=.*/ETH=$ETH/" .env
sed -i "s/^IPADDR_GTW=.*/IPADDR_GTW=$IPADDR_GTW/" .env
sed -i "s/^IPADDR=.*/IPADDR=$IPADDR/" .env
sed -i "s/^NETADDR=.*/NETADDR=$NETADDR/" .env
docker network rm $NETWEB 2> /dev/null
docker network rm $NETLAN 2> /dev/null

sudo fuser --kill 80/tcp > /dev/null 2>&1
sudo fuser --kill 443/tcp > /dev/null 2>&1

echo "* "
echo "* Build and Start docker services"

# Used by /lib/systemd/system/docker.service
cat << EOF > ./docker-iproute.sh
#!/bin/sh
#
# https://collabnix.com/2-minutes-to-docker-macvlan-networking-a-beginners-guide/
#
# ip route
# 192.0.0.0/6 dev macvlan0 proto kernel scope link src 192.168.1.22
# 192.168.1.16/29 dev macvlan0 scope link

# subnet 192.168.1.16/29 = 192.168.1.17 --> 192.168.1.22, Hosts: 6
ip link delete $NETLAN 2> /dev/null
#ip addr flush dev $NETLAN
#ip route del $NETADDR.16/29 dev $NETLAN scope link

ip link add $NETLAN link $ETH type macvlan mode bridge
#ip addr add $NETADDR.22/6 dev $NETLAN
ip addr add $NETADDR.22/29 dev $NETLAN
ip link set $NETLAN up
#ip route add $NETADDR.16/29 dev $NETLAN
EOF
chmod +x docker-iproute.sh
sudo ./docker-iproute.sh
[ -z "$(cat /lib/systemd/system/docker.service | grep docker-iproute.sh)" ] && sudo sed -i '/^ExecStart=.*/i ExecStartPre=/home/media/docker-media/docker-iproute.sh' /lib/systemd/system/docker.service && sudo systemctl daemon-reload
[ -z "$(cat /lib/systemd/system/docker.service | grep docker-autorestart.sh)" ] && sudo sed -i '/^ExecStart=.*/a ExecStartPost=/home/media/docker-media/docker-autorestart.sh' /lib/systemd/system/docker.service && sudo systemctl daemon-reload

docker network create --driver bridge $NETWEB > /dev/null
docker network create --driver macvlan --opt parent=$ETH --subnet $NETADDR.0/24 --gateway $IPADDR_GTW --ip-range $NETADDR.16/29 $NETLAN > /dev/null
docker-compose up -d --remove-orphans

echo "* "
echo "* Restart linked services"
sudo systemctl restart vboxweb-service > /dev/null 2>&1
sleep 3
if [ "$(systemctl status vboxweb-service | awk '/Active/{print $2}')" != "active" ] || [ $(systemctl status vboxweb-service | grep "vboxwebsrv --background" | wc -l) -eq 0 ]; then
  sleep 3
  sudo systemctl restart vboxweb-service
  if [ "$(systemctl status vboxweb-service | awk '/Active/{print $2}')" != "active" ] || [ $(systemctl status vboxweb-service | grep "vboxwebsrv --background" | wc -l) -eq 0 ]; then
    echo "* "
    echo "* [VBox] Start vboxweb-service.service failed! \nPlease check the log..."
    echo "* "
  fi
fi
sudo systemctl restart kodi

echo "* "
echo -n "* Remove unused volumes and images? [Y/n] "
read answer
if [ -n "$(echo $answer | grep -i '^y')" ] || [ -z "$answer" ]; then
  echo "* "
  docker system prune --all --volumes --force
fi

cd - > /dev/null
exit 0
