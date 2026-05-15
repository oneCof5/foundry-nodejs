# foundry-nodejs

My personal dockerized [FoundryVTT](http://foundryvtt.com) server using node.js

> [!NOTE]
> **Credit to Felddy**
> Much of the logic and concepts are borrowed liberally from [felddy/foundryvtt-docker](https://github.com/felddy/foundryvtt-docker).
> I happily utilized Felddy's image, but wanted a personalized version for my
> own for hobbyist purposes.

## Explicit Versions and Timed URLs

The FoundryVTT version (e.g. 14.361) is passed explicitly as the FVTT_VERSION .env variable.
The actuall installation checks for a zip file matching the pattern FoundryVTT-Node-${FVTT_VERSION}.zip within the FVTT_DATA_DIR/InstallerCache folder.
The zip installer may be predownloaded from FoundryVTT via:

- a timed URL passed via the FVTT_RELEASE_URL .env variable
- a downloaded .zip file saved to the FVTT_DATA_DIR/InstallerCache folder.

> [!IMPORTANT]
> For either approach (timed url or predownloaded zip), ensure that the FoundryVTT release uses the Node rather than Linux OS.

## Docker Run

> [!IMPORTANT]
> Always set a stable `--hostname` in `docker run`).  
> Foundry binds its software license to the container hostname, and if no.
> hostname is set, Docker assigns a random container ID on each container
> start.  This causes license verification to fail.

``` sh
docker run -d 
    --name foundryvtt-local 
    --hostname foundryvtt-local 
    -p 30000:30000 
    -e TZ=America/New_York 
    -e PUID=1000 
    -e PGID=1000 
    -e FVTT_VERSION=14.361 
    -e FVTT_PORT=30000 
    -e FVTT_HOSTNAME=mydomain.com 
    -v /data/fvtt/secrets/admin_password:/run/secrets/foundry_admin_password:ro 
    -v /data/fvtt/secrets/license_key:/run/secrets/foundry_license_key:ro 
    -v /data/fvtt/secrets/release_url:/run/secrets/foundry_release_url:ro 
    -v /data/fvtt/secrets/password_salt:/run/secrets/foundry_password_salt:ro 
    -v /data/fvtt/data:/data 
    -v /data/fvtt/logs:/logs 
    -v /cache/fvtt/app:/foundryvtt 
    foundryvtt-nodejs:local
```

## Environmental Variables

The tables below outline required and necessary environmental variables used by the container.

### Container Secrets

This container supports passing sensitive values via [Docker secrets](https://docs.docker.com/engine/swarm/secrets/).
The secrets are read from the container's `/run/secrets/foundry_${secret-name}`
location mapped via volume mounts.

| ENV VAR | REQUIRED | DEFAULT | NOTES |
| ---------------------------- | -------- | ------- | ------------------------ |
| FVTT_ADMIN_PASSWORD | :white_check_mark: | | Assign the admin password. |
| FVTT_PASSWORD_SALT | :x: | | A customized password salt. |
| FVTT_LICENSE_KEY | :white_check_mark: | | Assign the FoundryVTT license key |
| FVTT_RELEASE_URL | :white_check_mark: | | The timed URL to download a new version of FoundryVTT (Node) |

### Container Operations

| ENV VAR | REQUIRED | DEFAULT | NOTES |
| ---------------------------- | -------- | ------- | ------------------------ |
| PUID | :white_check_mark: | 911 | The user id to run the container against (e.g. 99 for nobody) |
| PGID | :white_check_mark: | 911 | The group id to run the container against (e.g. 100 for users) |
| FVTT_VERSION | :white_check_mark: | | The major and minor version (e.g. 14.361) |
| FVTT_KEEP_PRIOR_COPIES | :x: | 5 | How many prior versions to retain in the /InstallerCache |
| FVTT_LOCAL_HOSTNAME | :x: | localhost | |
| FVTT_VERBOSE_LOGGING | :x: | false | Capture Debug logging? |
| FVTT_LOG_KEEP_ROTATED | :x: | 10 | Number of log files to retain in history |
| FVTT_LOG_TO_STDERR | :x: | true | Log to STDERR |
| FVTT_LOG_USE_COLOR | :x: | true | Logs use color coding? |
| FVTT_APP_DIR | :x: | /foundryvtt | Container path for app installation (match volume mounts) |
| FVTT_DATA_DIR | :x: | /data | Container path for data (contains Config, Data, Logs) (match volume mounts) |
| FVTT_LOGS_DIR | :x: | /logs | Container path for logs (match volume mounts) |

### Options.json

See **Using Options.json** on [Application Configuration](https://foundryvtt.com/article/configuration/)  
Where indicated below as 'Admin UI' in notes below, this option is available
via the Config (gears option) in the WebUI while logged in as an adminstrator
user.

| ENV VAR | REQUIRED | DEFAULT | NOTES |
| ---------------------------- | -------- | ------- | ------------------------ |
| FVTT_AWS_CONFIG | :x: | | `awsConfig` value. |
| FVTT_COMPRESS_SOCKET | :x: | false | `compressSocket` Admin UI: **Server Configuration:Compress Web Socket Data**. *Enable compression of data sent from the server to the client via websocket. This is recommended for network performance.* |
| FVTT_COMPRESS_STATIC | :x: | false | `compressStatic` Admin UI: **Server Configuration:Compress Static Files**. *Compress files served by the Foundry Virtual Tabletop web server before sending them to the client to reduce the amount of data transferred.* |
| FVTT_HOSTNAME | :x: | fvtt.mydomain.com | `hostname` value. |

### Command Line Flags

See **Command Line Flag Listing** on [Application Configuration](https://foundryvtt.com/article/configuration/)  

| ENV VAR | REQUIRED | DEFAULT | NOTES |
| ---------------------------- | -------- | ------- | ------------------------ |
| FVTT_NOUPDATE | :x: | true | This disables the package updating system for the core software, preventing Foundry VTT from checking if there are new core software updates available. |
| FVTT_WORLD | :x: | | The id of the default world which the software will attempt to launch upon container start. |
