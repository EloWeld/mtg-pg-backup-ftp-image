#!/bin/bash

docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/s390x,linux/ppc64le,linux/riscv64 -t jannikhst/postgres-backup-ftp --push .