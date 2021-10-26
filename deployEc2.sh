#!/bin/bash

echo "Iniciando deploy EC2 AWS"

cd 0-terraform
/usr/bin/terraform init
/usr/bin/terraform apply -auto-approve

echo  "Aguardando a criação das maquinas ..."
sleep 20
