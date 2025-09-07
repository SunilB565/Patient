provider "aws" {
  region = "us-east-1"
}

# ---------------- VPC ----------------
resource "aws_vpc" "patient_vpc" {
  cidr_block           = "10.180.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "patient-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.patient_vpc.id

  tags = {
    Name = "patient-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.patient_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "patient-public-rt"
  }
}

# ---------------- Public Subnets ----------------
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.patient_vpc.id
  cidr_block              = "10.180.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "patient-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  =_
