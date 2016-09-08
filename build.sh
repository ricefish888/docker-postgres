#!/bin/bash

PACKAGE="postgres"
VERSION="9.5.4"

set -e

echo "> 1. Building Docker image"
echo ""
docker build -t donbeave/$PACKAGE:$VERSION .

#echo ""
#echo "> 2. Publishing Docker image to Docker Hub"
#echo ""
#docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
#docker push donbeave/$PACKAGE:$VERSION
