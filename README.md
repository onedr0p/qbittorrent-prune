# qbittorrent-prune

Script to delete torrents from qBittorrent that have a tracker error like `Torrent not Registered` or `Unregistered torrent`. This script currently only supports monitoring up to 3 categories in qBittorrent to check for tracker errors.

This is like the [gist I posted for transmission](https://gist.github.com/onedr0p/8fd8455f08f4781cad9e01a1d65bc34f) but qBittorrent actually has a api to work with to make this easier.

## Envars

|Name|Description|Default|
|---|---|---|
|`CRON_SCHEDULE`|Cron schedule for when to run the script, make sure to wrap with quotes|`"0 */12 * * *"`|
|`LOG_LEVEL`|`0` disable logging, `1` log errors or torrents deleted, `2` log everything|`1`|
|`DRY_RUN`|Set this to `false` to actually delete torrents from qBittorrent|`true`|
|`QB_HOSTNAME`|qBittorrent host||
|`QB_USERNAME`|qBittorrent username||
|`QB_PASSWORD`|qBittorrent password||
|`QB_DELETE_FILES`|Set this to `false` to keep the files on disk, but delete from qBittorrent|`true`|
|`QB_CATEGORY_1`|Category in qBittorrent that will be checked, remove environment variable to disable|`CATEGORY_1`|
|`QB_CATEGORY_2`|Category in qBittorrent that will be checked, remove environment variable to disable|`CATEGORY_2`|
|`QB_CATEGORY_3`|Category in qBittorrent that will be checked, remove environment variable to disable|`CATEGORY_3`|

## Local Development

```bash
cp .env.sample .env
chmod +x qbittorrent-prune.sh
./qbittorrent-prune.sh
```

## Deployment example with docker-compose

```yml
version: '3.7'
services:
  qbittorrent-prune:
    image: onedr0p/qbittorrent-prune:latest
    environment:
      CRON_SCHEDULE: '"0 * * * *"'
      DRY_RUN: "true"
      QB_HOSTNAME: http://localhost:8080
      QB_USERNAME: qbittorrent
      QB_PASSWORD: qbittorrent
      QB_DELETE_FILES: "true"
      QB_CATEGORY_1: radarr
      QB_CATEGORY_2: sonarr
```
