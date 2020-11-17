#!/bin/bash
APP_NAME=Configure-RabbitMQ
APP_BASE=/soft/warehouse-apps-1.0/Configure-Rabbitmq
PYTHON_BASE=${APP_BASE}/`cat python/lib/python*/orig-prefix.txt`
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
PIPENV_BASE=${APP_BASE}/python
source ${PIPENV_BASE}/bin/activate
PYTHON_BIN=python3

${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin declare queue --vhost=xsede name=amie.to.$1 durable=true 'arguments={"policy":"amie-default"}' 
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin declare queue --vhost=xsede name=amie.from.$1 durable=true 'arguments={"policy":"amie-default"}' 

  #declare queue name=... [node=... auto_delete=... durable=... arguments=...]

${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin declare exchange --vhost=xsede name=amie.to.$1 type=topic durable=true
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin declare exchange --vhost=xsede name=amie.from.$1 type=topic durable=true

${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin --vhost="xsede" declare binding source="amie.to.$1" destination_type="queue" destination="amie.to.$1" routing_key="#"
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin --vhost="xsede" declare binding source="amie.from.$1" destination_type="queue" destination="amie.from.$1" routing_key="#"



#rabbitmqadmin delete queue --vhost=xsede name=testqueue
