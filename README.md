# AWS EKS 기반 Spring Boot 애플리케이션 배포 프로젝트

이 프로젝트는 AWS EKS를 사용하여 Spring Boot 애플리케이션을 배포하는 인프라스트럭처를 Terraform으로 구성합니다.

## 인프라스트럭처 구성

### 네트워크 구성
- VPC CIDR: 10.21.0.0/16
- Public Subnet: 10.21.1.0/24, 10.21.2.0/24 (ap-northeast-2a, ap-northeast-2c)
- Private Subnet: 10.21.32.0/24, 10.33.2.0/24 (ap-northeast-2a, ap-northeast-2c)
- NAT Gateway: 각 AZ별 구성
- Internet Gateway: Public Subnet 연결

### EKS 클러스터
- 관리형 노드 그룹이 Private Subnet에 위치
- 각 AZ에 노드 분산 배치
- ALB Controller 설치 및 구성 (blueprint addon 활용)

### 애플리케이션 배포
- Spring Boot 애플리케이션 컨테이너화
- Pod affinity를 통한 관리형 노드 배치
- ALB를 통한 인터넷 접근 구성 (ALB DNS 통해 http 접근 가능)

## 사용 방법

1. Terraform 초기화
```bash
terraform init
```

2. 실행 계획 확인
```bash
terraform plan
```

3. 인프라스트럭처 배포
```bash
terraform apply
```

4. 인프라스트럭처 삭제
```bash
terraform destroy
```

## 주의사항
- AWS CLI와 kubectl, docker가 설치되어 있어야 합니다.
- 적절한 AWS 자격 증명이 구성되어 있어야 합니다.
- Docker가 설치되어 있어야 합니다.