# qbittorrent-prune

Script to delete torrents from qBittorrent that have a tracker error like `Torrent not Registered` or `Unregistered torrent`. This script currently only supports monitoring up to 3 categories in qBittorrent to check for tracker errors.

[![Docker Pulls](https://img.shields.io/docker/pulls/onedr0p/qbittorrent-prune)](https://hub.docker.com/r/onedr0p/qbittorrent-prune)

## Usage

### Run with Docker Compose

See examples in the [examples/compose](./examples/compose/) directory

### Run with Kubernetes

See examples in the [examples/kubernetes](./examples/kubernetes/) directory

## Configuration

| Name                | Description                                                                 | Default | Required |
|---------------------|-----------------------------------------------------------------------------|---------|:--------:|
| `LOG_LEVEL`         | `0` disable logging, `1` log errors or torrents deleted, `2` log everything | `1`     |    ❌     |
| `DRY_RUN`           | Set this to `false` to actually delete torrents from qBittorrent            | `true`  |    ❌     |
| `QB_URL`            | qBittorrent URL                                                             |         |    ✅     |
| `QB_USERNAME`       | qBittorrent username                                                        |         |    ✅     |
| `QB_PASSWORD`       | qBittorrent password                                                        |         |    ✅     |
| `QB_DELETE_FILES`   | Set this to `false` to keep the files on disk, but delete from qBittorrent  | `true`  |    ❌     |
| `QB_CATEGORIES`     | Comma delimited list of categories in qBittorrent that will be checked      |         |    ✅     |
| `PUSHOVER_USER_KEY` | Set to your Pushover User Key to enable notifications                       |         |    ❌     |
| `PUSHOVER_TOKEN`    | Set to your Pushover Application Key to enable notifications                |         |    ❌     |
| `PUSHOVER_PRIORITY` | Set Pushover notification priority                                          | `-1`    |    ❌     |
