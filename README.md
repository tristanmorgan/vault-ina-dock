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

Importing root certs
--------------------

The containers are so bare that they do not even have root certificates to verify the identity of AWS endpoints. to fix that run the following to extract a ca-bundle for your system.

    ./root-certs.sh

Usage
-----

Once the containers are built run docker compose and the Consul cluster should be formed. Vault will be un-initialised. 

    docker-compose up

Once running initialise Vault with the init.sh script and its ready for (testing) use.

    ./init.sh

Backups
-------

To backup the KV store and ACL from Consul (and all the Vault data with it) try at [Consulate](https://github.com/gmr/consulate)

TLS Certs
---------

You can also create your own slef signed certificates and even use them for the communication to Consul and Vault and between the two. The gets stuck in a bootstrap cenario where you use Vault to generate the certificates but need certificates to start Vault. replace the "tls_..." lines with "tls_disable = 1" to start without TLS, generate your certificates and then stop and restart after reverting.

Redundancy Zones
----------------

run the following to set the meta flag

    $ consul operator autopilot set-config  -redundancy-zone-tag=rz 
