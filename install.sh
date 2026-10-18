#!/bin/bash

cd /usr/local;
mkdir chromeforge_run && cd chromeforge_run
curl -LOf https://github.com/casper1051/chromeforge/raw/refs/heads/main/install_main.sh
bash install_main.sh
