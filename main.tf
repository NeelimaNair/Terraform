provider "aws" {
  region = "ap-southeast-2" # Sydney
}

locals {
  tags = merge(
    {
      "CostCentre"          = var.costCentre
      "Environment"         = var.tag_environment
      "Service"             = var.service
      "ServiceOwner"        = var.serviceOwner
      "ServiceDescription"  = var.serviceDescription
      "ServiceOwnerGroup"   = var.serviceOwnerGroup
      "TechnicalContact"    = var.technicalContact
      "TechnicalContactGroup" = var.technicalContactGroup
      "DataClassification"  = var.dataClassification
      "DeploymentType" = var.deploymentType
      "Deployer"      = var.deployer       
      "DeploymentDateTime" = timestamp() # RFC3339 UTC, e.g. 2026-01-23T02:25:00Z
    },
    var.tags
  )  
  vpce_ips = flatten([
    for eni in data.aws_network_interface.vpce_enis : [
      for pip in eni.private_ips : pip.private_ip_address
    ]
  ])

}

# -------------------------------
# VPC and Subnets
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(
    local.tags,
    {
      Name = "vpc-${var.env}-mel-${var.project}"
    }
  )
}

resource "aws_subnet" "sub_mel_PROJECT_01" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"
  tags = merge(
    local.tags,
    {
      Name = "sub-${var.env}-mel-${var.project}-${var.subnet1_suffix}"
    }
  )
}

resource "aws_subnet" "sub_mel_PROJECT_02" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2b"

  
  tags = merge(
    local.tags,
    {
      Name = "sub-${var.env}-mel-${var.project}-${var.subnet1_suffix}"
    }
  )

}



# -------------------------------
# S3 Bucket
# -------------------------------
resource "aws_s3_bucket" "static_files_s3" {
  bucket = "internal.de"

  tags        = local.tags

  # Optional: avoid perpetual diffs on this tag by ignoring changes
  lifecycle {
    ignore_changes = [tags["DeploymentDateTime"]]
  }

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
    aws_security_group.sgr_Stg_mel_PROJECT_02.id
  ]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint_subnet_association" "vpcsubnet_Stg_mel_PROJECT_01" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_vpc_endpoint.id
  subnet_id       = aws_subnet.sub_mel_PROJECT_01.id
}

resource "aws_vpc_endpoint_subnet_association" "vpcsubnet_Stg_mel_PROJECT_02" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_vpc_endpoint.id
  subnet_id       = aws_subnet.sub_mel_PROJECT_02.id
}


# Load each ENI of the endpoint
data "aws_network_interface" "vpce_enis" {
  for_each = toset(aws_vpc_endpoint.s3_vpc_endpoint.network_interface_ids)
  id       = each.value
}


# -------------------------------
# Security Group for ALB
# -------------------------------
resource "aws_security_group" "sgr_Stg_mel_PROJECT_01" {
  vpc_id = aws_vpc.main.id
  name   = "sgr-${var.env}-mel-${var.project}-${var.sg1_suffix}"

  tags = merge(
    local.tags,
    {
      Name = "sub-${var.env}-mel-${var.project}-${var.sg1_suffix}"
    }
  )

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
resource "aws_security_group" "sgr_Stg_mel_PROJECT_02" {
  vpc_id = aws_vpc.main.id
  name   = "sgr-${var.env}-mel-${var.project}-${var.sg2_suffix}"  

  tags = merge(
    local.tags,
    {
      Name = "sub-${var.env}-mel-${var.project}-${var.sg2_suffix}"
    }
  ) 

  ingress {
    security_groups = [aws_security_group.sgr_Stg_mel_PROJECT_01.id]
    from_port   = 443
    protocol = "tcp"
    to_port     = 443
  }

}


# -------------------------------
# ALB
# -------------------------------
resource "aws_lb" "alb_Stg_mel_PROJECT_01" {  
  name               = "alb-Stg-mel-PROJECT-01"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sgr_Stg_mel_PROJECT_01.id]
  subnets            = [aws_subnet.sub_mel_PROJECT_01.id, aws_subnet.sub_mel_PROJECT_02.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "albtg_mel_project" {
  name     = "albtg-${var.env}-mel-${var.project}"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id
  target_type = "ip" 

  # Health checks via HTTP on port 80 with relaxed success codes
  health_check {
    enabled             = true
    protocol            = "HTTP"               # or TCP
    port                = "80"                 # Port override to match HTTP
    path                = "/"                  # S3 will respond even without Host header
    matcher             = "200,307,405"        # Added 307 & 405 to success codes
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  tags = local.tags
}


# Attach each discovered IP to the target group
resource "aws_lb_target_group_attachment" "vpce_ip_attachments" {
  for_each         = toset(local.vpce_ips)
  target_group_arn = aws_lb_target_group.albtg_mel_project.arn
  target_id        = each.value            # IP address
  port             = 443
}


resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.alb_Stg_mel_PROJECT_01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.albtg_mel_project.arn
  }

  tags = local.tags
}

# ---------------------------------------------
# Step 4: Redirect "*/" -> "/#{path}index.html"
# This prevents S3's default XML listing for trailing slashes
# ---------------------------------------------
resource "aws_lb_listener_rule" "redirect_trailing_slash" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 10

  action {
    type = "redirect"
    redirect {
      status_code = "HTTP_302"
      # Keep the original protocol/host/port/query; only rewrite the path
      protocol = "#{protocol}"
      host     = "#{host}"
      port     = "#{port}"
      query    = "#{query}"
      path     = "/#{path}index.html"
    }
  }

  condition {
    path_pattern {
      values = ["*/"]
    }
  }

  tags = local.tags
}

# -------------------------------
# PrivateLink Endpoint for ALB → S3
# -------------------------------
#resource "aws_vpc_endpoint_service" "alb_service" {
#  acceptance_required        = false
#  network_load_balancer_arns = [aws_lb.alb_Stg_mel_PROJECT_01.arn]
#}

#resource "aws_vpc_endpoint" "alb_endpoint" {
#  vpc_id             = aws_vpc.main.id
#  service_name       = aws_vpc_endpoint_service.alb_service.service_name
#  vpc_endpoint_type  = "Interface"
#  subnet_ids         = [aws_subnet.sub_Stg_mel_PROJECT_01.id, aws_subnet.sub_Stg_mel_PROJECT_02.id]
#  security_group_ids = [aws_security_group.sgr_Stg_mel_PROJECT_01.id]
#}