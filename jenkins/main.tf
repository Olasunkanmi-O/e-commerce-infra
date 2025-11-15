locals {
  name = "jenkins"
}

# Create a single-AZ VPC with one public subnet 
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs            = ["eu-west-2a", "eu-west-2b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name = "${local.name}-vpc"
  }
}

# # Fetch the most recent RedHat Enterprise Linux (RHEL) 9 AMI owned by RedHat
# data "aws_ami" "redhat" {
#   most_recent = true
#   owners      = ["309956199498"]

#   filter {
#     name   = "name"
#     values = ["RHEL-9*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }
# }

# # Generate a new RSA private key for the key pair
# resource "tls_private_key" "keypair" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# # Save the generated private key locally with restricted permissions
# resource "local_file" "private_key" {
#   content         = tls_private_key.keypair.private_key_pem
#   filename        = "${local.name}-key.pem"
#   file_permission = "660"
# }

# # Create an AWS key pair using the generated public key
# resource "aws_key_pair" "public_key" {
#   key_name   = "${local.name}-key"
#   public_key = tls_private_key.keypair.public_key_openssh
# }


# # Create IAM role for Jenkins server to assume  SSM role
# resource "aws_iam_role" "ssm-jenkins-role" {
#   name = "${local.name}-ssm-jenkins-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# # Attach AmazonSSMManagedInstanceCore policy to Jenkins IAM role
# resource "aws_iam_role_policy_attachment" "ssm-policy" {
#   role       = aws_iam_role.ssm-jenkins-role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# # 1. Define the IAM Policy for S3 Access
# resource "aws_iam_policy" "tf_backend_access_policy" {
#   name        = "${local.name}-tf-backend-access"
#   description = "Allows Jenkins Role to access Terraform S3 state"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       # S3 Permissions for State File (Replace bucket name)
#       {
#         "Sid": "S3StateBucketAccess",
#         "Effect": "Allow",
#         "Action": [
#           "s3:ListBucket",
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject"
#         ],
#         "Resource": [
#           "arn:aws:s3:::ecommerce-project-1232",
#           "arn:aws:s3:::ecommerce-project-1232/infra-build/*" 
#         ]
#       }
#     ]
#   })
# }

# # 2. Attach the new policy to your existing Jenkins Role
# # The policy attachment ensures the Jenkins server's role now has both SSM and S3 permissions.
# resource "aws_iam_role_policy_attachment" "tf_backend_policy_attachment" {
#   role       = aws_iam_role.ssm-jenkins-role.name
#   policy_arn = aws_iam_policy.tf_backend_access_policy.arn
# }



# # Create instance profile for Jenkins server
# resource "aws_iam_instance_profile" "ssm_instance_profile" {
#   name = "${local.name}-ssm-jenkins-profile"
#   role = aws_iam_role.ssm-jenkins-role.name
# }

# # Create a security group for Jenkins server allowing inbound traffic on port 8080 and all outbound traffic
# resource "aws_security_group" "jenkins_sg" {
#   name        = "${local.name}-sg"
#   description = "Jenkins server security group"
#   vpc_id      = module.vpc.vpc_id

#   # Allow inbound traffic only from ALB
#   ingress {
#     from_port       = 8080
#     to_port         = 8080
#     protocol        = "tcp"
#     security_groups = [aws_security_group.jenkins_alb_sg.id] 
#     description     = "Allow traffic from Jenkins ALB"
#   }

#   # Allow all outbound
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name        = "${local.name}-jenkins-sg"
#     Environment = "dev"
#   }
# }


# # Launch Jenkins EC2 instance in public subnet with key, IAM profile, and user data
# resource "aws_instance" "jenkins-server" {
#   ami                         = data.aws_ami.redhat.id # Latest RedHat AMI in region
#   instance_type               = "t2.large"
#   key_name                    = aws_key_pair.public_key.key_name
#   associate_public_ip_address = true
#   subnet_id                   = module.vpc.public_subnets[0]
#   vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
#   iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

#   # Configure root volume: 20 GB, gp3 type, encrypted
#   root_block_device {
#     volume_size = 30
#     volume_type = "gp3"
#     encrypted   = true
#   }

#   # User data script for Jenkins setup with region variable
#   user_data = templatefile("./jenkins_userdata.sh", {
#     region            = var.reg,
#     TERRAFORM_VERSION = "1.9.5",
#     RELEASE_VERSION   = ""
#   })

#   # Require IMDSv2 tokens for metadata service security
#   metadata_options {
#     http_tokens = "required"
#   }

#   tags = {
#     Name = "${local.name}-server"
#   }
# }

# Get the public Route53 hosted zone for the domain name
data "aws_route53_zone" "acp_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

# Create DNS records in Route53 for ACM certificate domain validation
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.acp_zone.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true

  depends_on = [aws_acm_certificate.acm_cert]
}

# Validate the ACM certificate after the DNS records have been created
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.acm_cert.arn

  validation_record_fqdns = [
    for record in values(aws_route53_record.acm_validation_record) : record.fqdn
  ]

  # Ensure DNS records are created before attempting validation
  depends_on = [
    aws_acm_certificate.acm_cert,
    aws_route53_record.acm_validation_record
  ]
}

# create Route 53 record for kops  
resource "aws_route53_zone" "kops_zone" {
  name = "ecommerce.${var.domain_name}"
}

resource "aws_route53_record" "kops_ns_delegate" {
  zone_id = data.aws_route53_zone.acp_zone.id
  name    = "ecommerce.${var.domain_name}"
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.kops_zone.name_servers
}

# # Fetch availability zones for the region (used for ELB placement)
# data "aws_availability_zones" "available" {}

# resource "aws_security_group" "jenkins_alb_sg" {
#   name        = "${local.name}-jenkins-alb-sg"
#   description = "Allow HTTP/HTTPS traffic to Jenkins ALB"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow HTTPS traffic"
#   }

#   # Optional: HTTP redirect
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow HTTP traffic (optional, can redirect to HTTPS)"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${local.name}-jenkins-alb-sg"
#   }
# }

# # Target group for jenkins 
# resource "aws_lb_target_group" "jenkins_tg" {
#   name     = "jenkins-tg"
#   port     = 8080
#   protocol = "HTTP"
#   vpc_id   = module.vpc.vpc_id

#   health_check {
#     path                = "/"          # Jenkins responds here
#     protocol            = "HTTP"
#     matcher             = "200-399"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 3
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name = "${local.name}-jenkins-tg"
#   }
# }

# # application loadbalancer
# resource "aws_lb" "jenkins_alb" {
#   name               = "jenkins-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.jenkins_alb_sg.id]
#   subnets            = module.vpc.public_subnets

#   enable_deletion_protection = false

#   tags = {
#     Name = "${local.name}-jenkins-alb"
#   }
# }

# #HTTPS listener
# resource "aws_lb_listener" "jenkins_https" {
#   load_balancer_arn = aws_lb.jenkins_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.acm_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.jenkins_tg.arn
#   }
# }

# #HTTP -> HTTPS redirects 
# resource "aws_lb_listener" "jenkins_http" {
#   load_balancer_arn = aws_lb.jenkins_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

# # target group attachment 
# resource "aws_lb_target_group_attachment" "jenkins_instance" {
#   target_group_arn = aws_lb_target_group.jenkins_tg.arn
#   target_id        = aws_instance.jenkins-server.id  # or use ASG instances
#   port             = 8080
# }


# # Create Route 53 record for jenkins server
# resource "aws_route53_record" "jenkins" {
#   zone_id = data.aws_route53_zone.acp_zone.id
#   name    = "jenkins.${var.domain_name}"
#   type    = "A"

#   alias {
#   name                   = aws_lb.jenkins_alb.dns_name
#   zone_id                = aws_lb.jenkins_alb.zone_id
#   evaluate_target_health = true
#  }
# }


