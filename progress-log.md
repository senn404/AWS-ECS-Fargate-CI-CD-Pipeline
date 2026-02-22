# Progress Log — AWS ECS Fargate CI/CD Pipeline

---

## Phase 1: Khởi tạo Project (13/10/2025)

| Commit | Nội dung |
|---|---|
| `6326fec` | Initial commit |
| `ef9f10f` | Tạo cấu trúc Terraform ban đầu (provider, main, variables) — 10 files, 443 dòng |
| `8c0190a` | Thêm `.gitignore` |
| `06fded9` | Xóa file nhạy cảm: `.terraform.lock.hcl`, `terraform.tfstate`, `terraform.tfstate.backup` |
| `b32d39a` | Thêm sơ đồ kiến trúc `eco-green.drawio.svg` |
| `e396183` | Thêm lại `.terraform.lock.hcl` |

---

## Phase 2: Xây dựng EC2 Infrastructure (14/10/2025)

| Commit | Nội dung |
|---|---|
| `ab2d476` | Chuyển folder `terraform/` → `infrastructure/`. Tạo `ec2-server.tf`, `network.tf`. Thêm script cài đặt cho Jenkins, Grafana, Nexus, SonarQube |
| `8294b01` | Cập nhật sơ đồ kiến trúc mới `ECS-Deployer-Diagram.svg` |
| `f6a02aa` | Tạo 4 server CI/CD (Jenkins, SonarQube, Grafana, Nexus) bằng `for_each` — 62 dòng thay đổi |
| `b99c3f8` | Cấu hình `root_block_device` cho EC2, cập nhật CIDR blocks trong network |
| `558aa11` | Thêm `ec2_instance_state` resource và `outputs.tf` — quản lý trạng thái EC2 và xuất thông tin |

---

## Phase 3: ALB & Networking (15-16/10/2025)

| Commit | Nội dung |
|---|---|
| `0d969e5` | Tạo ALB cho EC2 Server. Tách file `ec2-network.tf` (201 dòng). Thêm `turn-on-system.tf`. Cập nhật script Jenkins |
| `c894811` | Hoàn thiện ALB: thêm listener rules, target groups. Viết script Docker cho Grafana, Nexus, SonarQube |
| `d665627` | **Fix bug:** AWS chỉ tạo 1 CNAME cho domain + subdomain → sử dụng 1 CNAME chung cho validation |

---

## Phase 4: Tối ưu hóa (22-23/10/2025)

| Commit | Nội dung |
|---|---|
| `dd7fc42` | Nâng cấp instance type: `t3.small` → `t3.medium` |
| `72d7359` | Tinh gọn EC2 Network config |

---

## Phase 5: Refactor Infrastructure (01/2026)

| Commit | Nội dung |
|---|---|
| `b01fdfd` | Cập nhật `.gitignore` toàn diện (27 dòng) |
| `4e2a203` | Commit infrastructure changes, thêm `.terraform.lock.hcl` |
| `2f2f298` | **Refactor lớn:** Đổi tên `ec2-network.tf` → `ec2-alb.tf`. Tách network ra `network.tf` (95 dòng mới) — tổ chức lại cấu trúc ALB rõ ràng hơn |
| `d4ff4f1` | Tham chiếu tường minh VPC/Subnet trong toàn bộ infrastructure. Viết `README.md` chi tiết (237 dòng) |

---

## Phase 6: ECS Fargate & ECR (14-15/02/2026)

| Commit | Nội dung |
|---|---|
| `e68415a` | Xóa script cài đặt Nexus, loại bỏ Nexus khỏi server definitions |
| `0703202` | Cập nhật SonarQube Docker image lên latest. Tinh gọn `ec2-server.tf` |
| `4a105d4` | **Milestone lớn:** Implement ECS Fargate backend, tập trung hóa ALB + ACM + Route53, thêm CloudFront, tạo ECR (462 dòng thêm mới) |

---

## Phase 7: Jenkins CI/CD + IAM Roles (17-18/02/2026)

| Commit | Nội dung |
|---|---|
| `c2f725c` | Implement Jenkins CI/CD: thêm master/slave EC2, tạo IAM roles, thêm JenkinsFile, script slave, cập nhật network security groups |

### Các lỗi gặp phải và cách sửa

#### Lỗi 1: `Variables not allowed`
```
Error: Variables not allowed
  iam_instance_profile = aws_iam_instance_profile.jenkins.name
  Variables may not be used here.
```
- **Nguyên nhân:** Block `variable` chỉ chấp nhận giá trị tĩnh, không thể tham chiếu resource
- **Cách sửa:** Dùng string tĩnh `"jenkins"` thay vì `aws_iam_instance_profile.jenkins.name`
- **Bài học:** `variable` xử lý trước resource; dùng `locals` nếu cần tham chiếu resource

#### Lỗi 2: `Duplicate resource name`
```
Error: A aws_iam_role_policy_attachment resource named "slave" was already declared
```
- **Nguyên nhân:** Hai `aws_iam_role_policy_attachment` cùng tên `"slave"`
- **Cách sửa:** Đổi thành `"slave_ecr"` và `"slave_ssm"` — đặt tên theo pattern `{role}_{policy}`

#### Lỗi 3: `Reference to undeclared resource`
```
Error: A managed resource "aws_iam_role" "server" has not been declared
```
- **Nguyên nhân:** Instance profile tham chiếu `aws_iam_role.server` (không tồn tại)
- **Cách sửa:** Đổi thành `aws_iam_role.jenkins`

#### Lỗi 4: EC2 không nhận credentials sau recreate Instance Profile
```
Unable to locate credentials
```
- **Nguyên nhân:** Terraform destroy/recreate Instance Profile tạo ra ID mới, nhưng EC2 vẫn giữ reference cũ. IAM và EC2 là 2 service độc lập, không tự sync
- **Cách sửa:**
```bash
aws ec2 disassociate-iam-instance-profile --association-id <id>
aws ec2 associate-iam-instance-profile --iam-instance-profile Name=jenkins --instance-id <id>
```
- **Bài học:** Tránh destroy + recreate Instance Profile đã gắn vào EC2

#### Lỗi 5: SSM `TargetNotConnected`
```
An error occurred (TargetNotConnected) when calling the StartSession operation
```
- **Nguyên nhân:** SSM Agent cần restart sau khi gắn Instance Profile mới
- **Cách sửa:** `sudo systemctl restart amazon-ssm-agent`
- **Yêu cầu SSM:** IAM Role có `AmazonSSMManagedInstanceCore` + SSM Agent chạy + Outbound 443

#### Lỗi 6: Jenkins Agent `WorkDirManager.initializeWorkDir` failed
```
WorkDirManager.initializeWorkDir → status=1/FAILURE, restart counter is at 61
```
- **Nguyên nhân:** Thư mục workDir chưa tồn tại hoặc sai quyền
- **Cách sửa:**
```bash
sudo mkdir -p /home/ec2-user/jenkins
sudo chown -R ec2-user:ec2-user /home/ec2-user/jenkins
sudo systemctl restart jenkins-agent
```

---

## Trạng thái hiện tại (18/02/2026)

### Đã hoàn thành
- [x] Tạo IAM Roles riêng cho Jenkins, SonarQube, Grafana, Slave
- [x] Gắn Instance Profile vào EC2 qua `for_each`
- [x] Cấu hình SSM cho tất cả EC2 instances
- [x] Xóa SSH port 22 khỏi Security Groups
- [x] Tạo Jenkins Security Group riêng với port 8080 + 50000 cho JNLP

### Đang thực hiện
- [ ] Fix Jenkins Agent systemd service trên slave
- [ ] Cấu hình Jenkins UI tạo Node với JNLP
- [ ] Terraform apply Security Group changes mới
