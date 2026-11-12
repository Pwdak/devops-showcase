locals {
  https_enabled = var.certificate_arn != ""
  ecr_registry  = split("/", var.ecr_repository_url)[0]
  ecr_name      = join("/", slice(split("/", var.ecr_repository_url), 1, length(split("/", var.ecr_repository_url))))
}

# ---------------------------------------------------------------- Logs
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "app" {
  name              = "/devops-showcase/app"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------- ALB
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "app" {
  name                       = "app-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnets
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name                 = "app-target-group"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }
}

# Sans certificat : HTTP -> forward. Avec certificat : HTTP -> redirection 443.
#tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.app.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------------------------------------------------------------- Launch template + ASG
resource "aws_launch_template" "app" {
  name_prefix   = "app-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ec2_sg_id]
  }

  # IMDSv2 obligatoire (protection contre le vol de credentials via SSRF).
  # hop_limit = 2 : indispensable pour que le conteneur Docker atteigne l'IMDS.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Toute modification (nouvelle image, nouveau commit) crée une nouvelle
  # version du template -> l'ASG déclenche un remplacement progressif.
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region     = var.aws_region
    ecr_registry   = local.ecr_registry
    ecr_repository = local.ecr_name
    image_tag      = var.image_tag
    git_repo_url   = var.git_repo_url
    git_ref        = var.git_ref
    db_host        = aws_db_instance.postgres.address
    db_name        = var.db_name
    db_secret_arn  = aws_db_instance.postgres.master_user_secret[0].secret_arn
    log_group      = aws_cloudwatch_log_group.app.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app" }
  }

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = var.private_subnets
  target_group_arns         = [aws_lb_target_group.app.arn]
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  health_check_type         = "ELB" # une instance non saine pour l'ALB est remplacée
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Déploiement sans interruption : une nouvelle instance saine est lancée
  # avant de retirer l'ancienne.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 180
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

# Scalabilité dynamique : maintient la CPU moyenne autour de 70 %
resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}

# ---------------------------------------------------------------- RDS
resource "aws_db_subnet_group" "db" {
  name       = "main-db-subnet-group"
  subnet_ids = var.db_subnets
}

#tfsec:ignore:aws-rds-enable-performance-insights
# Désactivée par défaut pour pouvoir détruire la démo ; activer en production (db_deletion_protection=true).
#tfsec:ignore:AVD-AWS-0177
resource "aws_db_instance" "postgres" {
  identifier            = "${var.project_name}-postgres"
  engine                = "postgres"
  engine_version        = "15"
  instance_class        = var.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  # AWS génère, stocke (Secrets Manager) et fait tourner le mot de passe :
  # il n'apparaît ni dans le code, ni dans le pipeline, ni dans les variables.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  iam_database_authentication_enabled = true
  multi_az                            = var.db_multi_az

  backup_retention_period    = var.db_backup_retention_days
  auto_minor_version_upgrade = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
  apply_immediately          = true
}
