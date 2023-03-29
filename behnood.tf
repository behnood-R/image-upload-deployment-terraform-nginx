# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC with CIDR block 100.122.115.0/24
resource "aws_vpc" "image-upload-api-vpc" {
  cidr_block = "100.122.115.0/24"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

# Create a public subnet within the VPC
resource "aws_subnet" "image-upload-api-vpc-public_subnet" {
  cidr_block = "100.122.115.0/25"
  vpc_id     = aws_vpc.image-upload-api-vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "image-upload-api-public-subnet"
  }
}

# Create a private subnet within the VPC
resource "aws_subnet" "image-upload-api-vpc-private_subnet" {
  cidr_block = "100.122.115.128/25"
  vpc_id     = aws_vpc.image-upload-api-vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "image-upload-api-vpc-private-subnet"
  }
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "image-upload-api-igw" {
  vpc_id = aws_vpc.image-upload-api-vpc.id

  tags = {
    Name = "image-upload-api-igw"
  }
}

# Create a NAT gateway
resource "aws_nat_gateway" "image-upload-api-nat_gw" {
  allocation_id = aws_eip.image-upload-api-eip.id
  subnet_id     = aws_subnet.image-upload-api-vpc-public_subnet.id

  tags = {
    Name = "image-upload-api-nat-gw"
  }
}

# Create an Elastic IP for the NAT gateway
resource "aws_eip" "image-upload-api-eip" {
  vpc = true

  tags = {
    Name = "image-upload-api-eip"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "image-upload-api-vpc-public_route_table" {
  vpc_id = aws_vpc.image-upload-api-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.image-upload-api-igw.id
  }

  tags = {
    Name = "image-upload-api-vpc-public-route-table"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "image-upload-api-vpc-public_route_table_association" {
  subnet_id      = aws_subnet.image-upload-api-vpc-public_subnet.id
  route_table_id = aws_route_table.image-upload-api-vpc-public_route_table.id
}

# Create a route table for the private subnet
resource "aws_route_table" "image-upload-api-vpc-private_route_table" {
  vpc_id = aws_vpc.image-upload-api-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.image-upload-api-nat_gw.id
  }

  tags = {
    Name = "image-upload-api-vpc-private-route-table"
  }
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "image-upload-api-vpc-private_route_table_association" {
  subnet_id      = aws_subnet.image-upload-api-vpc-private_subnet.id
  route_table_id = aws_route_table.image-upload-api-vpc-private_route_table.id
}

# Create a security group that allows SSH and HTTP traffic
resource "aws_security_group" "upload-image-api-security-group" {
  name_prefix = "upload-image-api-security-group"
  vpc_id      = aws_vpc.image-upload-api-vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port = 8001
    to_port = 8001
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch an EC2 instance running the latest Amazon Linux 2023 AMI
resource "aws_instance" "upload-image-api-instance" {
  ami           = "ami-007855ac798b5175e" # Replace with the latest Amazon Linux 2023 AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.image-upload-api-vpc-public_subnet.id
  associate_public_ip_address = true
  key_name      = var.key_name
  security_groups = [aws_security_group.upload-image-api-security-group.id]

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name = "upload-image-api-instance"
  }

  # User data to install Docker
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo \
              "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo apt install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo docker pull behnood/image-upload:latest
              sudo docker run -d -p 8000:8888 behnood/image-upload
              cat > /etc/nginx/sites-available/default << EOF2
              server {
                  listen 8001 default_server;
                  listen [::]:8001 default_server;
                  server_name _;
                  location / {
                      proxy_pass http://localhost:8000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  }
              }
              EOF2
              sudo systemctl restart nginx
              EOF

#   connection {
#     type        = "ssh"
#     user        = "ec2-user"
#     private_key = file(var.private_key_path)
#     host        = self.public_ip
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt-get update",
#       "sudo apt-get install ca-certificates curl gnupg",
#       "sudo mkdir -m 0755 -p /etc/apt/keyrings",
#       "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
#       "echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"


#       "sudo systemctl start docker",
#       "sudo docker pull behnood/image-upload:latest",
#       "sudo docker run -d -p 0.0.0.0:8000:8888 behnood/image-upload"
#     ]
#   }
}

# Output the public IP address of the instance
output "public_ip" {
  value = aws_instance.upload-image-api-instance.public_ip
}