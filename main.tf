provider "aws" {
  region = "ap-southeast-2" # Sydney
}

# -------------------------------
# VPC and Subnets
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2b"
}

# -------------------------------
# S3 Bucket
# -------------------------------
resource "aws_s3_bucket" "static_files_s3" {
  bucket = "internal.de"
}

resource "aws_s3_bucket_policy" "allow_vpc_endpoint" {
  bucket = aws_s3_bucket.static_files_s3.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_files_s3.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3_vpc_endpoint.id
          }
        }
      },      
      {
        Effect: "Allow",
        Principal: "*",
        Action: "s3:ListBucket",
        Resource: "${aws_s3_bucket.static_files_s3.arn}",
        Condition: {
          StringEquals: {
            "aws:SourceVpce": aws_vpc_endpoint.s3_vpc_endpoint.id
          }
        }
      }
    ]
  })
}

# -------------------------------
# VPC Endpoint for S3
# -------------------------------
resource "aws_vpc_endpoint" "s3_vpc_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-southeast-2.s3"
  vpc_endpoint_type = "Interface"  
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id
  ]
  private_dns_enabled = true
}

# -------------------------------
# Security Group for ALB
# -------------------------------
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  name   = "alb-sg"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Restrict to VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------
# Security Group for VPC Endpoint
# -------------------------------
resource "aws_security_group" "vpc_endpoint_sg" {
  vpc_id = aws_vpc.main.id
  name   = "vpc-endpoint-sg"   
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_sg_ingress_rule" {
  security_group_id = aws_security_group.vpc_endpoint_sg.id

  referenced_security_group_id   = aws_security_group.alb_sg.id
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

# -------------------------------
# ALB
# -------------------------------
resource "aws_lb" "internal_alb" {
  name               = "alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_lb_target_group" "s3_target" {
  name     = "s3-target"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3_target.arn
  }
}

# -------------------------------
# PrivateLink Endpoint for ALB → S3
# -------------------------------
#resource "aws_vpc_endpoint_service" "alb_service" {
#  acceptance_required        = false
#  network_load_balancer_arns = [aws_lb.internal_alb.arn]
#}

#resource "aws_vpc_endpoint" "alb_endpoint" {
#  vpc_id             = aws_vpc.main.id
#  service_name       = aws_vpc_endpoint_service.alb_service.service_name
#  vpc_endpoint_type  = "Interface"
#  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
#  security_group_ids = [aws_security_group.alb_sg.id]
#}