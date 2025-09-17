#!/bin/sh

BUILD_DOCKERFILE="Dockerfile.alpine"
BUILD_REG=ghcr.io/fabien-sanglier-ibm
BUILD_TAG=1.0.6-local

docker build \
    -t ${BUILD_REG}/continuous-curl-runner:${BUILD_TAG} \
    -f ${BUILD_DOCKERFILE} \
    .

echo "Done!!"
exit 0;