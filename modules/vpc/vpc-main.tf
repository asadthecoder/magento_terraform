provider "aws" {
  region = "us-east-1"
}
##############Additional Tags if needed to be added#############
variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}
#############Ports for SG #####################

variable "sg_ports"	{
		type = list(number)
		default = [22,443,80]
	}
################ VPC #################
resource "aws_vpc" "main" {
  cidr_block           = var.main_vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc-name
  }
}
################# Subnets #############
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone1
  tags = merge(var.additional_tags,
    {
      Name = "pub-subnet-1"
    },
  )
}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zone2
  map_public_ip_on_launch = true

  tags = merge(var.additional_tags,
    {
      Name = "pub-subnet-2"
    },
  )
}
resource "aws_subnet" "subnet3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.availability_zone1
  tags = {
    Name = "pvt-subnet-1"
  }
}
resource "aws_subnet" "subnet4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.availability_zone2

  tags = {
    Name = "pvt-subnet-2"
  }
}
######## IGW ###############
resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}
########### NAT ##############
resource "aws_eip" "nat" {
}
resource "aws_nat_gateway" "main-natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet1.id
  tags = {
    Name = "main-nat"
  }
}
############# Route Tables ##########
resource "aws_route_table" "main-public-rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-igw.id
  }
  tags = {
    Name = "main-public-rt"
  }
}
resource "aws_route_table" "main-private-rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main-natgw.id
  }
  tags = {
    Name = "main-private-rt"
  }
}
######### PUBLIC Subnet assiosation with rotute table    ######
resource "aws_route_table_association" "public-assoc-1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main-public-rt.id
}
resource "aws_route_table_association" "public-assoc-2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main-public-rt.id
}
########## PRIVATE Subnets assiosation with rotute table ######
resource "aws_route_table_association" "private-assoc-1" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.main-private-rt.id
}
resource "aws_route_table_association" "private-assoc-2" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.main-private-rt.id
}
########## Security Group Configuration for ELB/EC2 Instances ######
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id      = aws_vpc.main.id

  dynamic ingress {
    for_each = var.sg_ports
    content {
    from_port = ingress.value
    to_port = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
}
resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  cidr_blocks   = ["0.0.0.0/0"]
  from_port         = 0
  security_group_id = aws_security_group.allow_http.id
}
output "pub-subnet-1" { value = aws_subnet.subnet1.id }
output "pub-subnet-2" { value = aws_subnet.subnet2.id }
output "pvt-subnet-1" { value = aws_subnet.subnet3.id }
output "pvt-subnet-2" { value = aws_subnet.subnet4.id }
output "vpc-id" { value = aws_vpc.main.id }
output "http-https-sg" { value = aws_security_group.allow_http.id }
