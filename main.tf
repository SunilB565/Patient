terraform {
  backend "s3" {
    bucket         = "my-ecs-terraform-state-bucket"   # <-- Replace with your S3 bucket name
    key            = "ecs/terraform.tfstate"           # Path inside the bucket
    region         = "us-east-1"                       # Region of the bucket
    encrypt        = false
  }
}

provider "aws" {
  region = "us-east-1"
}

#----------------------------
# Variable for image tag
#----------------------------
variable "image_tag" {
  description = "Docker image tag for ECS task"
  type        = string
  default     = "latest"
}

#----------------------------
# 1. Create VPC and Subnets
#----------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ecs-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

#----------------------------
# 2. Security Group
#----------------------------
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#----------------------------
# 3. ECS Cluster
#----------------------------
resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"
}

#----------------------------
# 4. IAM Roles for ECS Task
#----------------------------
resource "aws_iam_role" "ecs_task_exec_role" {
  # Using name_prefix to avoid "EntityAlreadyExists" errors
  name_prefix = "ecs-task-exec-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Effect = "Allow",
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#----------------------------
# 5. ECS Task Definition
#----------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "patient-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([
    {
      name      = "patient"
      image     = "980921717654.dkr.ecr.us-east-1.amazonaws.com/patient:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

#----------------------------
# 6. ECS Fargate Service
#----------------------------
resource "aws_ecs_service" "app" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_a.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_exec_policy]
}
