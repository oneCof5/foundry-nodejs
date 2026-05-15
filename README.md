# foundry-nodejs
My personal dockerized FoundryVTT[http://foundryvtt.com] server using node.js

#### Credit to Felddy
I borrowed liberally from the felddy/foundryvtt-docker container, but wanted one of my own for hobbyist purposes.

> [!IMPORTANT]
> Always set a stable `hostname` in your `compose.yml` (or `--hostname` in
> `docker run`).  Foundry binds its software license to the container hostname.
> If no hostname is set, Docker assigns a random container ID on each start,
> causing license verification to fail after every restart.

## Secrets ##

This container supports passing sensitive values via [Docker secrets](https://docs.docker.com/engine/swarm/secrets/).
