FROM alpine AS builder
RUN apk add --no-cache curl unzip
ARG VAULT_VERSION=0.11.3
RUN curl -LO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
 && unzip vault_${VAULT_VERSION}_linux_amd64.zip -d /

FROM scratch
LABEL maintainer="Tristan Morgan <tristan@vibrato.com.au>"
LABEL Description="HashiCorp Vault in a single binary Container"
EXPOSE 8200 8201
COPY --from=builder /vault /
ENTRYPOINT ["/vault"]
CMD ["server","-dev","-dev-listen-address=0.0.0.0:8200"]
