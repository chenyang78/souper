#!/bin/sh -ex

tar cz Dockerfile update_deps.sh clone_and_test.sh CMakeLists.txt docs include lib runtime test tools utils unittests | docker build -t souperweb -
container=$(/usr/bin/docker run -d souperweb true)
docker export $container | docker import - souperweb_squashed
docker build -t souperweb_final - < Dockerfile.metadata
docker tag souperweb_final regehr/souperweb

# docker push regehr/souperweb
