locals {
    vpc_id   = "vpc-0735473c0650139ff"
    subnet   = "*treiname*" ### Nesse campo precisaremos fazer um filtro das suas subnets, nesse casoo faremos de todas que contém priv no nome.
}

data "aws_subnet_ids" "main" {
vpc_id = local.vpc_id
    filter {
        name = "tag:Name"
        values = [local.subnet]
    }
}

data "aws_ami" "ami_ec2" {
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["*terraform-k8s-*"]
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

provider "aws" {
  region = "sa-east-1"
}

resource "aws_instance" "k8s_proxy" {
  ami           = "ami-054a31f1b3bf90920"
  instance_type = "t2.large"
  subnet_id     = "subnet-0d2b94c1e14c65fec"
  associate_public_ip_address = true
  key_name      = "key_wrmeplt_v2"
  root_block_device {
    encrypted = true
  }
  tags = {
    Name = "k8s-haproxy-team4"
  }
  vpc_security_group_ids = [aws_security_group.acessos_workers.id]
}

resource "aws_instance" "k8s_masters" {
  ami           = data.aws_ami.ami_ec2.image_id
  subnet_id     = element(tolist(data.aws_subnet_ids.main.ids[*]), count.index)
  instance_type = "t2.large"
  associate_public_ip_address = true
  key_name      = "key_wrmeplt_v2"
  count         = 3
    root_block_device {
    encrypted = true
  }
  tags = {
    Name = "k8s-master-team4-${count.index}"
  }
  vpc_security_group_ids = [aws_security_group.acessos_master.id]
  depends_on = [
    aws_instance.k8s_workers,
  ]
}

resource "aws_instance" "k8s_workers" {
  ami           = data.aws_ami.ami_ec2.image_id
  subnet_id     = element(tolist(data.aws_subnet_ids.main.ids[*]), count.index)
  instance_type = "t2.large"
  associate_public_ip_address = true
  key_name      = "key_wrmeplt_v2"
  count         = 3
  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "k8s_workers-team4-${count.index}"
  }
  vpc_security_group_ids = [aws_security_group.acessos_workers.id]
}


resource "aws_security_group" "acessos_master" {
  name        = "k8s-acessos_master_team4"
  description = "Acessos maquina master"
  vpc_id      = data.aws_subnet_ids.main.id

  ingress = [
    {
      cidr_blocks      = ["10.0.1.0/24"]
      description      = "Libera acesso k8s_masters"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = true
      to_port          = 0
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Port range kubernetes"
      from_port        = 30000
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = true
      to_port          = 32767
    },
    {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["${chomp(data.http.myip.body)}/32"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null,
      security_groups : null,
      self : null
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = [],
      prefix_list_ids = null,
      security_groups: null,
      self: null,
      description: "Libera dados da rede interna"
    }
  ]

}


resource "aws_security_group" "acessos_workers" {
  name        = "k8s-workers_team4"
  vpc_id      = data.aws_subnet_ids.main.id
  description = "acessos inbound traffic"

  ingress = [
    {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["${chomp(data.http.myip.body)}/32"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null,
      security_groups : null,
      self : null
    },
    {
      cidr_blocks      = ["10.0.1.0/24"]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = true
      to_port          = 65535
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Port range kubernetes"
      from_port        = 30000
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = true
      to_port          = 32767
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = [],
      prefix_list_ids = null,
      security_groups: null,
      self: null,
      description: "Libera dados da rede interna"
    }
  ]

}

output "k8s-masters" {
  value = [
    for key, item in aws_instance.k8s_masters :
      "k8s-master${key+1} - ${item.private_ip} - ${item.public_dns} "
  ]
}

output "output-k8s_workers" {
  value = [
    for key, item in aws_instance.k8s_workers :
    "k8s-workers${key+1} - ${item.private_ip} - ${item.public_dns} "
  ]
}

output "output-k8s_proxy" {
  value = [
    "k8s_proxy - ${aws_instance.k8s_proxy.private_ip} - ${aws_instance.k8s_proxy.public_dns} "
  ]
}

