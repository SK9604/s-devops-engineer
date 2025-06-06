# ALB Controller 보안 그룹
resource "aws_security_group" "alb_controller" {
  name        = "${local.cluster_name}-alb-controller-sg"
  description = "Security group for ALB Controller"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.cluster_name}-alb-controller-sg"
  }
}

# ECR 레포지토리 생성
resource "aws_ecr_repository" "spring_boot" {
  name         = "spring-boot-app"
  force_delete = true
}

# ECR 레포지토리 정책
resource "aws_ecr_repository_policy" "spring_boot" {
  repository = aws_ecr_repository.spring_boot.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPull"
        Effect = "Allow"
        Principal = {
          AWS = module.eks.cluster_iam_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Spring Boot 애플리케이션 빌드 및 Docker 이미지 생성
resource "null_resource" "build_and_push" {
  triggers = {
    dockerfile_hash  = filemd5("${path.module}/Dockerfile")
    source_code_hash = filemd5("${path.module}/spring-boot-application/build.gradle")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/spring-boot-application"
    command     = <<-EOT
      # Gradle 빌드
      ./gradlew clean build
      
      # AWS ECR 로그인
      aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin ${aws_ecr_repository.spring_boot.repository_url}
      
      # Docker 이미지 빌드
      cd ..
      docker build --platform=linux/amd64 -t ${aws_ecr_repository.spring_boot.repository_url}:v1.0 .
      
      # ECR에 이미지 푸시
      docker push ${aws_ecr_repository.spring_boot.repository_url}:v1.0
    EOT
  }
}

# Spring Boot 애플리케이션 배포
resource "kubernetes_deployment" "spring_boot" {
  depends_on = [null_resource.build_and_push, module.eks]

  metadata {
    name = "spring-boot-app"
    labels = {
      app = "spring-boot-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "spring-boot-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "spring-boot-app"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "mgmt-node-group"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["spring-boot-app"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          image = "${aws_ecr_repository.spring_boot.repository_url}:v1.0"
          name  = "spring-boot-app"

          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# Service 생성
resource "kubernetes_service" "spring_boot" {
  depends_on = [kubernetes_deployment.spring_boot]

  metadata {
    name = "spring-boot-service"
  }

  spec {
    selector = {
      app = "spring-boot-app"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Ingress 생성
resource "kubernetes_ingress_v1" "spring_boot" {
  depends_on = [kubernetes_deployment.spring_boot, kubernetes_service.spring_boot]

  metadata {
    name = "spring-boot-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = jsonencode([{ "HTTP" = 80 }])
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.spring_boot.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} 