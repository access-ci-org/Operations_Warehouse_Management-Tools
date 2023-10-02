#!/bin/bash
#usage:  create_ipf_user.sh DN resource
input=$(sed -r 's/street=/2.5.4.9=/g' <<<"$1")
input=$(sed -r 's/postalCode=/2.5.4.17=/g' <<<"$input")
echo creating user $input
sudo rabbitmqctl add_user "$input" foo

sudo rabbitmqctl list_user_permissions "$input"

sudo rabbitmqctl set_permissions -p infopub "$input" "^amq.gen.*" "^amq.gen.*|^glue2.*" "^amq.gen.*|^glue2.*"
