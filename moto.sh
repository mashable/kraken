#!/bin/bash
if [ ! -f .virtualenv/bin/activate ] ; then
    virtualenv ./.virtualenv
fi
source .virtualenv/bin/activate
pip show moto > /dev/null
if [ $? -eq 1 ] ; then
    pip install moto
    
fi
pip show flask > /dev/null
if [ $? -eq 1 ] ; then
    pip install flask
fi

pkill -f "moto_server sqs -p 4883"
moto_server sqs -p 4883 > log/moto.log 2>&1 &