provider "aws" {
   region = "us-east-1"
   access_key = var.access_key
   secret_key = var.secret_key 
}

## For Windows to set variable run the below line in the terminal
## Set-Item -Path env:TF_VAR_user_name -Value "terraform_user"

## For linux and Mac users run the below line in the terminal
## export TF_VAR_user_name=terraform_user

# 1. Create vpc

resource "aws_vpc" "my-vpc" {
  cidr_block = "192.0.0.0/16"
  tags = {
    Name = "Project-2-vpc"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "my-Gateway" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
     Name = "Project-2-Internet-Gateway"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "my-route-Table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-Gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.my-Gateway.id
  }

  tags = {
    Name = "Project-2-RT"
  }
}

# 4. Create a subnet

resource "aws_subnet" "my-subnet" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = "192.0.0.0/16"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Project-2-subnet"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "my-Associate" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.my-route-Table.id
}

# 6. Create Security Group to allow ports 22,80,443 for Http $ Https

resource "aws_security_group" "allow-web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the custom subnet created above

resource "aws_network_interface" "network-interface" {
  subnet_id       = aws_subnet.my-subnet.id
  private_ips     = ["192.0.1.77"]
  security_groups = [aws_security_group.allow-web.id]

#   attachment {
#     instance     = aws_instance.server.id
#     device_index = 1
#   }
}

# 8. Assign an elastic IP to the network interface created above

resource "aws_eip" "EIP" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.network-interface.id
  associate_with_private_ip = "192.0.1.77"
  depends_on = [aws_internet_gateway.my-Gateway]
}

# 9. Create a Ubuntu server and install/enable apache2

resource "aws_instance" "server" {
  ami = "ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Terraform-key"
  tags = {
    Name = var.tag_name
  }
  #network interface
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.network-interface.id
  }
  #Copy local file to EC2
  provisioner "file" {
        source      = "./netflix.html"
        destination = "/home/ubuntu/page.html"
       
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${path.module}/Terraform-key.pem")}"
      host        = "${self.public_ip}"
    }
   }
  #CMD to install apache2 in the server
  user_data = file("${path.module}/script.sh")
}

variable "tag_name" {
  description = "value"
  type = string
  default = "terraform-apache2-server"
}

