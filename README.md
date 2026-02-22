# AWS ECS Fargate CI/CD Pipeline

End-to-End Deployment of a FullStack Web Application (Spring Boot, ReactJS) with AWS ECS Fargate, Terraform, Jenkins, SonarQube, Trivy & CloudWatch/Grafana

![Sơ đồ kiến trúc hệ thống](./ECS-Deployer-Diagram.svg)

## 📋 Mục lục

- [Tổng quan](#-tổng-quan)
- [Kiến trúc hệ thống](#-kiến-trúc-hệ-thống)
- [Sơ đồ Infrastructure](#-sơ-đồ-infrastructure)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Chi tiết Infrastructure](#-chi-tiết-infrastructure)
- [Cách sử dụng](#-cách-sử-dụng)
- [Truy cập các dịch vụ](#-truy-cập-các-dịch-vụ)

---

## 🎯 Tổng quan

Dự án này triển khai một hệ thống CI/CD hoàn chỉnh trên AWS sử dụng Terraform, với 2 phần chính:

### CI/CD Tools (EC2-based)
- **Jenkins** (Master): CI/CD automation server
- **Jenkins Slave** (x2): Build agents với Docker, Java 17, Maven, Git
- **SonarQube**: Code quality & security analysis
- **Grafana**: Monitoring & observability dashboard

### Application Workload (ECS Fargate)
- **ECS Fargate Cluster**: Chạy backend service (Spring Boot) trên containers
- **ECR Repository**: Lưu trữ Docker images cho backend
- **ALB + Route53**: Routing traffic qua `api.huanops.com`

### Chờ triển khai
- **S3 + CloudFront**: Hosting frontend (ReactJS) — *file placeholder*

---

## 🏗️ Kiến trúc hệ thống

### AWS Provider
- **Region**: `ap-southeast-1` (Singapore)
- **Terraform AWS Provider**: Version `~> 6.0`

### Network Architecture

#### VPC Configuration
| Resource | CIDR Block | AZ | Mô tả |
|----------|------------|-----|-------|
| VPC | `10.0.0.0/16` | — | Main VPC với DNS hostnames enabled |
| Public Subnet 1a | `10.0.1.0/24` | `ap-southeast-1a` | Auto-assign public IP |
| Public Subnet 1b | `10.0.2.0/24` | `ap-southeast-1b` | Auto-assign public IP |
| Private Subnet 1a | `10.0.3.0/24` | `ap-southeast-1a` | Reserved |
| Private Subnet 1b | `10.0.4.0/24` | `ap-southeast-1b` | Reserved |

#### Network Components
- **Internet Gateway** (`main-igw`): Cho phép truy cập internet cho public subnets
- **Route Table** (`public-rt`): Route `0.0.0.0/0` → Internet Gateway, gán cho cả 2 public subnets

### Security Groups

#### ALB Security Group (`alb-sg`)
| Direction | Port | Protocol | Source | Mô tả |
|-----------|------|----------|--------|-------|
| Ingress | 443 | TCP | `0.0.0.0/0` | HTTPS access |
| Ingress | 80 | TCP | `0.0.0.0/0` | HTTP access |
| Egress | All | All | `0.0.0.0/0` | All outbound traffic |

#### EC2 Server Security Group (`ec2-server-sg`)
> Dùng cho SonarQube và Grafana

| Direction | Port | Protocol | Source | Mô tả |
|-----------|------|----------|--------|-------|
| Ingress | 8080 | TCP | ALB SG | Web access from ALB |
| Egress | All | All | `0.0.0.0/0` | All outbound traffic |

#### Jenkins Security Group (`jenkins-sg`)
| Direction | Port | Protocol | Source | Mô tả |
|-----------|------|----------|--------|-------|
| Ingress | 8080 | TCP | ALB SG | Web access from ALB |
| Ingress | 8080 | TCP | Slave SG | Jenkins API from slave |
| Ingress | 50000 | TCP | Slave SG | JNLP agent connection |
| Egress | All | All | `0.0.0.0/0` | All outbound traffic |

#### Slave Security Group (`slave-sg`)
| Direction | Port | Protocol | Source | Mô tả |
|-----------|------|----------|--------|-------|
| Egress | All | All | `0.0.0.0/0` | All outbound traffic |

#### ECS Security Group (`ecs-sg`)
| Direction | Port | Protocol | Source | Mô tả |
|-----------|------|----------|--------|-------|
| Ingress | 80 | TCP | ALB SG | HTTP from ALB |
| Egress | All | All | `0.0.0.0/0` | All outbound traffic |

---

## 📊 Sơ đồ Infrastructure

### Tổng quan kiến trúc AWS

```mermaid
graph TB
    subgraph Internet
        User["👤 User / Developer"]
    end

    subgraph AWS["☁️ AWS Cloud - ap-southeast-1"]
        subgraph Route53["Route53 DNS - huanops.com"]
            DNS_Jenkins["jenkins.huanops.com"]
            DNS_Sonar["sonar-qube.huanops.com"]
            DNS_Grafana["grafana.huanops.com"]
            DNS_API["api.huanops.com"]
        end

        ACM["🔒 ACM Certificate<br/>*.huanops.com"]
        ECR["📦 ECR<br/>backend-repo"]

        subgraph VPC["VPC 10.0.0.0/16"]
            IGW["🌐 Internet Gateway"]

            subgraph PublicSubnets["Public Subnets"]
                subgraph AZ_1a["AZ: ap-southeast-1a"]
                    PubSub1a["10.0.1.0/24"]
                end
                subgraph AZ_1b["AZ: ap-southeast-1b"]
                    PubSub1b["10.0.2.0/24"]
                end
            end

            ALB["⚖️ ALB - ec2-server-alb<br/>Internet-facing"]

            subgraph EC2["EC2 Instances - CI/CD Tools"]
                Jenkins["🔧 Jenkins Master<br/>t3.medium"]
                SonarQube["🔍 SonarQube<br/>t3.medium"]
                Grafana["📈 Grafana<br/>t3.medium"]
            end

            subgraph Slaves["EC2 Instances - Jenkins Slaves"]
                Slave1["⚙️ Slave-1<br/>t3.medium<br/>Docker + Java 17 + Maven"]
                Slave2["⚙️ Slave-2<br/>t3.medium<br/>Docker + Java 17 + Maven"]
            end

            subgraph ECSCluster["ECS Fargate - backend-cluster"]
                ECSService["🚀 backend-service<br/>CPU: 1024 / Mem: 2048<br/>Port: 80"]
            end

            subgraph PrivateSubnets["Private Subnets - Reserved"]
                PrivSub1a["10.0.3.0/24"]
                PrivSub1b["10.0.4.0/24"]
            end
        end
    end

    User -->|"HTTPS :443"| Route53
    Route53 -->|A Record Alias| ALB
    ACM -.->|SSL/TLS| ALB
    ALB -->|"Host: jenkins.*"| Jenkins
    ALB -->|"Host: sonar-qube.*"| SonarQube
    ALB -->|"Host: grafana.*"| Grafana
    ALB -->|"Host: api.*"| ECSService
    Jenkins ---|"JNLP :50000"| Slave1
    Jenkins ---|"JNLP :50000"| Slave2
    Slave1 -->|"Push Image"| ECR
    Slave2 -->|"Push Image"| ECR
    ECR -.->|"Pull Image"| ECSService

    style AWS fill:#232F3E,color:#fff
    style VPC fill:#1a472a,color:#fff
    style PublicSubnets fill:#2d5a3d,color:#fff
    style PrivateSubnets fill:#4a2d2d,color:#fff
    style ALB fill:#8C4FFF,color:#fff
    style ACM fill:#DD344C,color:#fff
    style Route53 fill:#8C4FFF,color:#fff
    style Jenkins fill:#D24939,color:#fff
    style SonarQube fill:#4E9BCD,color:#fff
    style Grafana fill:#F46800,color:#fff
    style ECSCluster fill:#FF9900,color:#fff
    style ECR fill:#FF9900,color:#fff
    style Slaves fill:#5C4033,color:#fff
```

### Luồng Traffic (Network Flow)

```mermaid
sequenceDiagram
    participant User as 👤 User
    participant DNS as Route53
    participant ALB as ALB :443
    participant TG_EC2 as EC2 Target Group :8080
    participant TG_ECS as ECS Target Group :80
    participant EC2 as EC2 Docker Container
    participant ECS as ECS Fargate Task

    User->>DNS: https://jenkins.huanops.com
    DNS->>ALB: A Record Alias → ALB
    Note over ALB: SSL Termination<br/>ACM *.huanops.com

    alt HTTP :80 Request
        ALB-->>User: 301 Redirect → HTTPS
    end

    alt Host: jenkins / sonar-qube / grafana
        ALB->>TG_EC2: Host-based routing → tg-{server}
        TG_EC2->>EC2: Forward :8080
        EC2-->>User: Response
    end

    alt Host: api.huanops.com
        ALB->>TG_ECS: Priority 100 → ecs-tg
        TG_ECS->>ECS: Forward :80
        ECS-->>User: Response
    end

    Note over ALB: Default: 404<br/>Service Not Found
```

### CI/CD Pipeline Flow

```mermaid
flowchart LR
    subgraph Developer
        Code["📝 Source Code<br/>Spring Boot"]
    end

    subgraph CI["CI - Jenkins Master + Slaves"]
        Build["🔨 Build<br/>Maven"]
        Test["🧪 Unit Test"]
        Scan["🔍 SonarQube<br/>Code Analysis"]
        DockerBuild["🐳 Docker Build"]
        Push["📦 Push to ECR"]
    end

    subgraph CD["CD - AWS ECS Fargate"]
        ECS["🚀 ECS Service<br/>Update Task Def"]
        ALBr["⚖️ ALB<br/>api.huanops.com"]
    end

    subgraph Monitor["Monitoring"]
        Graf["📈 Grafana<br/>Dashboard"]
    end

    Code -->|Git Push| Build
    Build --> Test
    Test --> Scan
    Scan -->|Quality Gate Pass| DockerBuild
    DockerBuild --> Push
    Push -->|New Image| ECS
    ECS --> ALBr
    ECS -.->|Metrics| Graf

    style CI fill:#D24939,color:#fff
    style CD fill:#232F3E,color:#fff
    style Monitor fill:#F46800,color:#fff
```

### Sơ đồ Terraform Resources

```mermaid
graph LR
    subgraph Net["🌐 network.tf"]
        VPC["aws_vpc.main-vpc"]
        Subnets["4x aws_subnet"]
        IGW["aws_internet_gateway.igw"]
        RT["aws_route_table.public-rt"]
        SG_EC2["aws_security_group.ec2-server-sg"]
        SG_Jenkins["aws_security_group.jenkins-sg"]
        SG_Slave["aws_security_group.slave-sg"]
    end

    subgraph ALBRes["⚖️ alb.tf"]
        SG_ALB["aws_security_group.alb"]
        ACM["aws_acm_certificate"]
        ALB["aws_alb.ec2-server-alb"]
        L80["listener :80 redirect"]
        L443["listener :443 HTTPS"]
        TG_Server["target_group x3 EC2"]
        TG_ECS["target_group ECS"]
        R53["route53_record x4"]
    end

    subgraph EC2Res["🖥️ ec2-server.tf"]
        Servers["aws_instance.server x3"]
        Slaves["aws_instance.slave x2"]
    end

    subgraph IAMRes["🔑 iam-role.tf"]
        Roles["IAM Roles x4<br/>jenkins, sonarqube,<br/>grafana, slave"]
    end

    subgraph ECSRes["� ecs - backend.tf"]
        Cluster["aws_ecs_cluster"]
        TaskDef["aws_ecs_task_definition"]
        Service["aws_ecs_service"]
        ECS_Roles["IAM: agent + task role"]
        ECS_SG["aws_security_group.ecs-sg"]
    end

    subgraph ECRRes["� ecr.tf"]
        ECR["aws_ecr_repository<br/>backend-repo"]
    end

    VPC --> Subnets & IGW & SG_EC2 & SG_Jenkins & SG_Slave & SG_ALB
    SG_ALB --> ALB
    ALB --> L80 & L443
    ACM --> L443
    L443 --> TG_Server & TG_ECS
    TG_Server --> Servers
    TG_ECS --> Service
    Roles --> Servers & Slaves
    ECS_Roles --> TaskDef --> Service
    Cluster --> Service
    ECR -.-> TaskDef

    style Net fill:#1a472a,color:#fff
    style ALBRes fill:#8C4FFF,color:#fff
    style EC2Res fill:#D24939,color:#fff
    style IAMRes fill:#DD344C,color:#fff
    style ECSRes fill:#FF9900,color:#fff
    style ECRRes fill:#FF9900,color:#fff
```

---

## 📁 Cấu trúc thư mục

```
.
├── ECS-Deployer-Diagram.svg    # Sơ đồ kiến trúc tổng quan (SVG)
├── JenkinsFile                 # Jenkins pipeline definition (chờ triển khai)
├── README.md
└── infrastructure/
    ├── provider.tf              # AWS Provider (ap-southeast-1, v6.0)
    ├── network.tf               # VPC, Subnets, IGW, Route Tables, Security Groups
    ├── alb.tf                   # ALB, ACM, Route53, Listeners, Target Groups (EC2 + ECS)
    ├── ec2-server.tf            # EC2: Jenkins, SonarQube, Grafana + 2 Slave nodes
    ├── iam-role.tf              # IAM Roles: jenkins, sonarqube, grafana, slave (SSM + ECR)
    ├── ecr.tf                   # ECR Repository: backend-repo
    ├── ecs - backend.tf         # ECS Fargate: Cluster, Task Def, Service, IAM Roles, SG
    ├── outputs.tf               # Terraform outputs (EC2 + Slave info)
    ├── turn-on-system.tf        # EC2 instance state management (ensure running)
    ├── s3-bucket.tf             # (Chờ triển khai - S3 Frontend)
    ├── cloudfront.tf            # (Chờ triển khai - CloudFront CDN)
    └── ec2-install/             # User data scripts
        ├── jenkins.sh           # Jenkins: jenkins/jenkins:lts-jdk21 → :8080
        ├── sonar-qube.sh        # SonarQube: sonarqube:latest → 9000→8080
        ├── grafana.sh           # Grafana: grafana/grafana:latest → 3000→8080
        └── slave.sh             # Slave: Docker + Java 17 + Maven + Git
```

---

## 🖥️ Chi tiết Infrastructure

### EC2 Instances — CI/CD Servers

Tất cả EC2 instances sử dụng:
- **AMI**: `ami-02fb5ef6a4a46a62d` (Amazon Linux)
- **Subnet**: Public Subnet 1a
- **Volume**: gp3, delete on termination
- **IAM Instance Profile**: Mỗi server có role riêng với `AmazonSSMManagedInstanceCore`

| Server | Instance Type | Volume Size | Health Check Path | Docker Image | Port Mapping | Security Group |
|--------|---------------|-------------|-------------------|--------------|--------------|----------------|
| Jenkins | `t3.medium` | 20 GB | `/health` | `jenkins/jenkins:lts-jdk21` | 8080:8080 | `jenkins-sg` |
| SonarQube | `t3.medium` | 20 GB | `/api/system/status` | `sonarqube:latest` | 8080:9000 | `ec2-server-sg` |
| Grafana | `t3.medium` | 20 GB | `/api/health` | `grafana/grafana:latest` | 8080:3000 | `ec2-server-sg` |

### EC2 Instances — Jenkins Slaves

| Server | Instance Type | Volume Size | IAM Policy | Software |
|--------|---------------|-------------|------------|----------|
| Slave-1 | `t3.medium` | 20 GB | `AmazonEC2ContainerRegistryFullAccess` + SSM | Docker, Java 17, Maven, Git |
| Slave-2 | `t3.medium` | 20 GB | `AmazonEC2ContainerRegistryFullAccess` + SSM | Docker, Java 17, Maven, Git |

> Slave nodes kết nối Jenkins Master qua JNLP (port 50000) và có quyền push Docker images lên ECR.

### ECS Fargate — Backend Service

| Property | Value |
|----------|-------|
| Cluster | `backend-cluster` |
| Service | `backend-service` (desired count: 1) |
| Task Family | `backend-task` |
| Launch Type | `FARGATE` |
| CPU / Memory | 1024 / 2048 |
| Network Mode | `awsvpc` |
| Container Port | 80 |
| Current Image | `public.ecr.aws/nginx/nginx:stable-perl-amd64` (placeholder) |
| Subnets | Public Subnet 1a, 1b |
| Security Group | `ecs-sg` |

**IAM Roles:**
- **Execution Role** (`ecs-agent-role`): `AmazonECSTaskExecutionRolePolicy` — pull images, push logs
- **Task Role** (`ecs-task-role`): `AmazonECSTaskExecutionRolePolicy` — runtime permissions

### ECR Repository

| Property | Value |
|----------|-------|
| Name | `backend-repo` |
| Tag Mutability | MUTABLE |
| Scan on Push | Enabled |

### Application Load Balancer

- **Name**: `ec2-server-alb`
- **Type**: Application Load Balancer (internet-facing)
- **Subnets**: Public Subnet 1a, 1b

#### Listeners & Routing

| Port | Protocol | Action |
|------|----------|--------|
| 80 | HTTP | Redirect to HTTPS (301) |
| 443 | HTTPS | Host-based routing → Target Groups |

**Routing Rules:**

| Priority | Host Header | Target Group | Target Type | Port |
|----------|-------------|--------------|-------------|------|
| 10+ | `jenkins.huanops.com` | `tg-jenkins` | instance | 8080 |
| 10+ | `sonar-qube.huanops.com` | `tg-sonar-qube` | instance | 8080 |
| 10+ | `grafana.huanops.com` | `tg-grafana` | instance | 8080 |
| 100 | `api.huanops.com` | `ecs-tg` | ip | 80 |
| Default | — | — | — | 404 |

### SSL/TLS Certificate

- **Domain**: `huanops.com` (wildcard: `*.huanops.com`)
- **Provider**: AWS Certificate Manager (ACM)
- **Validation**: DNS validation via Route53 (tự động)

### DNS Configuration (Route53)

| Subdomain | Target |
|-----------|--------|
| `jenkins.huanops.com` | ALB (A Record Alias) |
| `sonar-qube.huanops.com` | ALB (A Record Alias) |
| `grafana.huanops.com` | ALB (A Record Alias) |
| `api.huanops.com` | ALB (A Record Alias) |

### IAM Roles

| Role | Service | Policies |
|------|---------|----------|
| `jenkins` | EC2 | `AmazonSSMManagedInstanceCore` |
| `sonarqube` | EC2 | `AmazonSSMManagedInstanceCore` |
| `grafana` | EC2 | `AmazonSSMManagedInstanceCore` |
| `slave` | EC2 | `AmazonEC2ContainerRegistryFullAccess`, `AmazonSSMManagedInstanceCore` |
| `ecs-agent-role` | ECS Tasks | `AmazonECSTaskExecutionRolePolicy` |
| `ecs-task-role` | ECS Tasks | `AmazonECSTaskExecutionRolePolicy` |

---

## 🚀 Cách sử dụng

### Prerequisites

1. AWS CLI configured với credentials
2. Terraform installed (>= 1.0)
3. SSH key pair tại `~/.ssh/ec2-server.pub`
4. Domain `huanops.com` được quản lý trên Route53

### Triển khai

```bash
# Di chuyển vào thư mục infrastructure
cd infrastructure

# Khởi tạo Terraform
terraform init

# Xem trước các thay đổi
terraform plan

# Triển khai infrastructure
terraform apply
```

### Xem thông tin Instances

```bash
# Thông tin CI/CD servers (Jenkins, SonarQube, Grafana)
terraform output ec2-info

# Thông tin Jenkins slave nodes
terraform output slave
```

Output hiển thị: Instance ID, Public/Private IP & DNS, Instance Type, IAM Profile, State, Tags.

---

## 🌐 Truy cập các dịch vụ

Sau khi triển khai thành công, truy cập các dịch vụ qua HTTPS:

| Service | URL | Flow |
|---------|-----|------|
| Jenkins | https://jenkins.huanops.com | ALB :443 → EC2 :8080 → Container :8080 |
| SonarQube | https://sonar-qube.huanops.com | ALB :443 → EC2 :8080 → Container :9000 |
| Grafana | https://grafana.huanops.com | ALB :443 → EC2 :8080 → Container :3000 |
| Backend API | https://api.huanops.com | ALB :443 → ECS Fargate :80 |

---

## 📝 Ghi chú

### Files chưa triển khai
- `JenkinsFile`: Jenkins pipeline definition
- `s3-bucket.tf`: S3 Bucket cho Frontend Static (ReactJS)
- `cloudfront.tf`: CloudFront CDN distribution

### Docker Containers (EC2)
- **Persistent volumes** để lưu trữ data
- **Auto-restart policy** (`--restart always`)
- **Port mapping** về port 8080 cho ALB health check
- **User data scripts** tự động cài Docker và chạy container khi EC2 khởi tạo

### Terraform Patterns
- **`for_each`** trên `server_definitions` và `slave_definitions`: EC2, Target Groups, Listener Rules, DNS Records
- **`locals`** cho security group mapping: Jenkins dùng `jenkins-sg`, còn lại dùng `ec2-server-sg`
- **`depends_on`** đảm bảo thứ tự: ACM → ALB Listener, EC2 → Instance State → Output

---

## 🔐 Bảo mật

- HTTPS được enforce với redirect từ HTTP → HTTPS
- SSL certificate wildcard `*.huanops.com` validate qua DNS tự động
- **Jenkins** có security group riêng, chỉ cho phép ALB và Slave truy cập
- **Slave** chỉ có egress, không expose port nào
- **ECS** chỉ cho phép traffic từ ALB (port 80)
- EC2 servers không mở SSH (truy cập qua **SSM Session Manager** nhờ IAM role)
- Slave có quyền **ECR Full Access** để push Docker images

---

## 📊 Monitoring

- **Grafana**: Dashboard visualization, đã triển khai tại `grafana.huanops.com`
- **CloudWatch**: Thu thập logs và metrics từ ECS (dự kiến)

---

## 🏷️ Tags

Tất cả resources được tag với:
- `Project`: `ECS-CI/CD`
- `Name`: Tên resource tương ứng
