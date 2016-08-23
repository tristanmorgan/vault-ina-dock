Vault ina Dock
==============

Example of [Hashicorp Vault](https://www.vaultproject.io/) running inside [Docker](https://www.docker.com/) with [HashiCorp Consul](https://www.consul.io/) running in a cluster as the storage backend.

Only requires Docker, Docker Compose and a shell.

Building the Containers
-----------------------

Inside both consul and vault folders are build.sh scripts that will build minimal containers with only the Go binary
downloaded from [HashiCorp](https://www.hashicorp.com/).

    cd consul
    ./build.sh
    
    cd vault
    ./build.sh

Usage
-----

Once the containers are built run docker compose and the Consul cluster should be formed. Vault will be un-initialised. 

    docker-compose up

Once running initialise Vault with the init.sh script and its ready for (testing) use.

    ./init.sh

Backups
-------

To backup the KV store and ACL from Consul (and all the Vault data with it) try at [Consulate](https://github.com/gmr/consulate)
