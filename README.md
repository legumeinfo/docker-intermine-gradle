# docker-intermine-gradle

You can use these docker images to create your own InterMine instance.

## Requirements

 - [Docker](https://docs.docker.com/install/)
 - [Docker compose](https://docs.docker.com/compose/install/)

## Quickstart

### LIS datastore

On the host OS, mount the data store at ./data/mine/data 

e.g., for macOS:

    mount_webdav https://data.legumeinfo.org/dav ./data/mine/data

for a GitHub codespace:

    sudo apt update && sudo apt install -y fuse rclone

    rclone mount --daemon --webdav-url https://data.legumeinfo.org/dav --allow-non-empty --allow-other --attr-timeout 24h --dir-cache-time 24h --poll-interval 0 --vfs-cache-mode full --vfs-read-chunk-size 64k :webdav:/ ./data/mine/data

Run the command to build the image and load the database:

```bash
docker-compose run --remove-orphans load
docker-compose up
```

Visit **`localhost:9999/minimine`** to see your new mine.

### Environment variables

| ENV variable  | Description | Default | Example |
| ------------- | ------------- | ------------- | ------------- |
| MINE_NAME  | Name of your mine | minimine | minimine |
| TOMCAT_HOST_PORT | Tomcat will bind to this port on your host machine | 9999 | 1234 |

### Configs

Set any mine properties in intermine_builder/web.properties.
The [entrypoint.sh](intermine_builder/entrypoint.sh) script will replace select uppercase placeholders with generated usernames and passwords from the corresponding environment variables.

### Change default settings (optional)

You can configure a lot of options by creating a `.env` file in the current working directory and adding the required key value pairs. These are used as env vars by docker-compose. For example:
```bash
MINE_NAME=humanmine
```
