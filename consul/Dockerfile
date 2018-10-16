FROM alpine AS builder
RUN apk add --no-cache curl unzip
ARG CONSUL_VERSION=1.3.0
RUN curl -LO https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip \
 && unzip consul_${CONSUL_VERSION}_linux_amd64.zip -d /

FROM scratch
LABEL maintainer="Tristan Morgan <tristan@vibrato.com.au>"
LABEL Description="HashiCorp Consul in a single binary Container"
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8443 8500 8600 8600/udp
WORKDIR /
COPY --from=builder /consul /
ENTRYPOINT ["/consul"]
CMD ["agent","-server","-dev"]
