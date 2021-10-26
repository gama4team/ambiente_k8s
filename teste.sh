#!/bin/bash
cd 2-ansible/01-k8s-install-masters_e_workers/

ansible-playbook -i hosts teste.yml -u ubuntu --private-key /var/lib/jenkins/.ssh/id_rsa

sleep 5
