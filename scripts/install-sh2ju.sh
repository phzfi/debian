#!/bin/bash
#Install sh2ju, a JUnit compliant test framework for Bash
#@see http://manolocarrasco.blogspot.fi/2010/02/hudson-publish-bach.html

cd /usr/src/
if [ ! -d shell2junit ]; then
     git clone https://github.com/manolo/shell2junit.git
else
     cd shell2junit
     git pull
     cd ..
fi

apt install -y bc
