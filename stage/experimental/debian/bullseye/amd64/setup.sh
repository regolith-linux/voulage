#!/bin/bash

# This PPA adds nececessary backports for debbuild helper 13
sudo apt install -y software-properties-common

sudo add-apt-repository --remove -y ppa:videolan/master-daily
sudo add-apt-repository -y ppa:videolan/master-daily