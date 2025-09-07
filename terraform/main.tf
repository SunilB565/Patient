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
  vpc_id                  = aws_vpc.patient_vpc.id
  cidr_block              = "10.180.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "patient-public-subnet-2"
  }
}

# Associate route table with subnets
resource "aws_route_table_association" "subnet1_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet2_assoc" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------- Security Group ----------------
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-patient-sg"
  description = "Allow HTTP and 3000 for ECS"
  vpc_id      = aws_vpc.patient_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-patient-sg"
  }
}

# ---------------- ECS Cluster ----------------
resource "aws_ecs_cluster" "patient_cluster" {
  name = "patient-cluster"
}

# ---------------- IAM Role ----------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "patient-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------- ECS Task Definition ----------------
resource "aws_ecs_task_definition" "patient_task" {
  family                   = "patient-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "patient"
    image     = "548586340409.dkr.ecr.ap-south-1.amazonaws.com/patient:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
  }])
}

# ---------------- Load Balancer ----------------
resource "aws_lb" "patient_alb" {
  name               = "patient-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
}

resource "aws_lb_target_group" "patient_tg" {
  name        = "patient-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.patient_vpc.id
  target_type = "ip" # required for Fargate

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.patient_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.patient_tg.arn
  }
}

# ---------------- ECS Service ----------------
resource "aws_ecs_service" "patient_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.patient_cluster.id
  task_definition = aws_ecs_task_definition.patient_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.patient_tg.arn
    container_name   = "patient"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http_listener]
}

# ---------------- Outputs ----------------
output "alb_dns_name" {
  value       = aws_lb.patient_alb.dns_name
  description = "Public DNS of the ALB to access patient service"
}
