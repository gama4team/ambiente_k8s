echo "iniciando o ansible"

cd 2-ansible/01-k8s-install-masters_e_workers

ANSIBLE_OUT=$(ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts provisionar.yml -u ubuntu --private-key ~/.ssh/id_rsa)

#### Mac ###
#K8S_JOIN_MASTER=$(echo $ANSIBLE_OUT | grep -oE "(kubeadm join.*?certificate-key.*?)'" | sed 's/\\//g' | sed "s/'t//g" | sed "s/'//g" | sed "s/,//g")
#K8S_JOIN_WORKER=$(echo $ANSIBLE_OUT | grep -oE "(kubeadm join.*?discovery-token-ca-cert-hash.*?)'" | head -n 1 | sed 's/\\//g' | sed "s/'t//g" | sed "s/'//g" | sed "s/'//g" | sed "s/,//g")

echo "listando variaveis com a config do join kube"

#### Linux ###
K8S_JOIN_MASTER=$(echo $ANSIBLE_OUT | grep -oP "(kubeadm join.*?certificate-key.*?)'" | sed 's/\\//g' | sed "s/'t//g" | sed "s/'//g" | sed "s/,//g")
K8S_JOIN_WORKER=$(echo $ANSIBLE_OUT | grep -oP "(kubeadm join.*?discovery-token-ca-cert-hash.*?)'" | head -n 1 | sed 's/\\//g' | sed "s/'t//g" | sed "s/'//g" | sed "s/'//g" | sed "s/,//g")

echo "Aqui lista"

echo $K8S_JOIN_MASTER
echo $K8S_JOIN_WORKER

cat <<EOF > 2-provisionar-k8s-master-auto-shell.yml
- hosts:
  - ec2-k8s-m2
  become: yes
  tasks:
    - name: "Reset cluster 2"
      shell: "kubeadm reset -f"

    - name: "Fazendo join kubernetes master"
      shell: $K8S_JOIN_MASTER

    - name: "Colocando no path da maquina o conf do kubernetes"
      shell: mkdir -p ~/.kube && sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config && export KUBECONFIG=/etc/kubernetes/admin.conf
#---
- hosts:
  - ec2-k8s-m3
  become: yes
  tasks:
    - name: "Reset cluster 3"
      shell: "kubeadm reset -f"

    - name: "Fazendo join kubernetes master"
      shell: $K8S_JOIN_MASTER

    - name: "Colocando no path da maquina o conf do kubernetes"
      shell: mkdir -p ~/.kube && sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config && export KUBECONFIG=/etc/kubernetes/admin.conf
#---
- hosts:
  - ec2-k8s-w1
  - ec2-k8s-w2
  - ec2-k8s-w3
  become: yes
  tasks:
    - name: "Reset cluster"
      shell: "kubeadm reset -f"

    - name: "Fazendo join kubernetes worker"
      shell: $K8S_JOIN_WORKER

#---
- hosts:
  - ec2-k8s-m1
  become: yes
  tasks:
    - name: "Configura weavenet para reconhecer os nós master e workers"
      shell: kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=\$(kubectl version | base64 | tr -d '\n')"
EOF

ansible-playbook -i hosts 2-provisionar-k8s-master-auto-shell.yml -u ubuntu --private-key /var/lib/jenkins/.ssh/id_rsa

