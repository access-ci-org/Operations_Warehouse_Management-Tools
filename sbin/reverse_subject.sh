#!/bin/bash
#echo $1 |sed 's/\n//g'|sed 's//^\//' |tac -s'/' |sed 's/\//,/g'
echo $1 |sed 's/\n//g'|sed 's/$/\//'| sed 's/\/\/$/\//'|tac -s'/' |sed 's/\//,/g'|sed 's/\,*$//g'
