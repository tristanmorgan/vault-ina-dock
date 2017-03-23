FROM scratch
MAINTAINER Tristan Morgan <tristan@vibrato.com.au>
LABEL Description="HashiCorp Consul in a single binary Container"
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8443 8500 8600 8600/udp
WORKDIR /
COPY consul /
ENTRYPOINT ["/consul"]
CMD ["agent","-server","-ui","-data-dir=/data"]
