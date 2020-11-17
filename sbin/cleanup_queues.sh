#!/bin/bash
APP_NAME=Configure-RabbitMQ
APP_BASE=/soft/warehouse-apps-1.0/Configure-Rabbitmq
PYTHON_BASE=${APP_BASE}/`cat python/lib/python*/orig-prefix.txt`
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
PIPENV_BASE=${APP_BASE}/python
source ${PIPENV_BASE}/bin/activate
PYTHON_BIN=python3

${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin delete queue --vhost=xsede name=amie.to.$1
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin delete queue --vhost=xsede name=amie.from.$1
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin delete exchange --vhost=xsede name=amie.to.$1
${PYTHON_BIN} /soft/warehouse-apps-1.0/Configure-Rabbitmq/PROD/sbin/rabbitmqadmin delete exchange --vhost=xsede name=amie.from.$1
