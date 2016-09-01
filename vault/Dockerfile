FROM scratch
MAINTAINER Tristan Morgan <tristan@vibrato.com.au>
LABEL Description="HashiCorp Vault in a single binary Container"
EXPOSE 8200
COPY vault /
ENTRYPOINT ["/vault"]
CMD ["server","-dev"]
