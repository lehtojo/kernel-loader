#!/bin/bash
rm boot.o
v1 ./loader/ -objects -system -windows
make && ./image.sh && ./start.sh $@
