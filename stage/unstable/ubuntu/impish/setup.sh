#!/bin/bash

set -e

# Add Focal repo for ilia dependencies
sudo add-apt-repository -y 'deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse'
sudo add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ focal main restricted'
sudo add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ focal-updates main restricted'
sudo add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ focal universe'
sudo add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ focal-updates universe'
