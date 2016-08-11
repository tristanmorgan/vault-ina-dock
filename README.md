Vault ina Dock
==============

Example of Hashicorp Vault running inside Docker with HashiCorp Consul running in a cluster as the storage backend.

Only requires Docker, Docker Compose and a shell.

Building the Containers
-----------------------

Inside both consul and vault folders are build.sh scripts that will build minimal containers with only the Go binary
downloaded from HashiCorp.

    cd consul
    ./build.sh
    
    cd vault
    ./build.sh

Usage
-----

Once the containers are built run docker compose and the Consul cluster should be formed. Vault will be un-initialised. 

    docker-compose up

Once running initialise Vault, unseal it and its ready for (testing) use.

    export VAULT_ADDR=http://120.0.0.1:8200
    vault init
    vault unseal
