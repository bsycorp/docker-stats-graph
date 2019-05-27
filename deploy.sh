#!/bin/bash
docker login -u $DOCKERUSER -p $DOCKERPASS
docker build . -t bsycorp/docker-stats-graph:$TRAVIS_BRANCH
docker push bsycorp/docker-stats-graph