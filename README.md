# HTPC media Dockerized Applications based on Ubuntu - docker-compose w/ watchtower, traefik, portainer, glances, vbox-http, certs-extraction, muximux, nzbget, jackett, qbittorrent, bazarr, radarr, sonarr, lidarr, emby, owncloud, redis, onlyoffice, motioneye, iperf3

## Requirements
* Ubuntu 18.04 LTS or more
* `Add hostname` or static lease on your router `to target HTPC IP address` (and the `Local domain: local`) (for local reverse-proxy setup):
  * media.htpc.local
  * monit.htpc.local
  * proxy.htpc.local
  * docker.htpc.local
  * vm.htpc.local
  * nzbget.htpc.local
  * jackett.htpc.local
  * qbittorrent.htpc.local
  * bazarr.htpc.local
  * radarr.htpc.local
  * sonarr.htpc.local
  * lidarr.htpc.local
  * emby.htpc.local
  * htpc.local/owncloud
  * cam.htpc.local
* On your main router, `open firewall tcp ports` 80, 443 forward to target your HTPC IP address

## Install steps
1. Write SD card with the preinstalled image w/ Rufus, and power on the HTPC

4. Build and run docker applications

Setup is located on docker-media/`.env`
* `DOMAIN`: sub.example.com the domain name dns resolution

```bash
$ echo "htpc" > /etc/hostname
$ git clone https://github.com/joweisberg/docker-media.git
$ cd $HOME/docker-media && ./docker-build.sh
```

7. HTPC web access:

* http://media.htpc.local/ - HTPC console management
![](https://raw.githubusercontent.com/joweisberg/rpi-docker-owncloud/master/.img/muximux.png)
* https://sub.example.com/owncloud (default login/password: admin/owncloud)
![](https://raw.githubusercontent.com/joweisberg/rpi-docker-owncloud/master/.img/owncloud.png)
