# Progress Log — IAM Role, SSM & Jenkins Agent Setup

> **Ngày:** 2026-02-17 → 2026-02-18
> **Project:** AWS ECS Fargate CI/CD Pipeline

---

## 1. Tạo IAM Policy cho S3 Access

### Mục tiêu
Viết Terraform policy cho phép EC2 instance (Jenkins) truy cập S3 thông qua IAM Role.

### Kiến thức đã học

| Khái niệm | Giải thích |
|---|---|
| **IAM Role** | Đối tượng được gán quyền, gồm Trust Policy + Permission Policy |
| **Trust Policy** (`assume_role_policy`) | Xác định ai/service nào được phép assume role |
| **Permission Policy** | Quyền cụ thể (S3, ECR, SSM...) |
| **Instance Profile** | Lớp bọc (wrapper) bắt buộc giữa IAM Role và EC2 |
| **`variable` vs `locals`** | Variable chỉ chứa giá trị tĩnh, locals có thể tham chiếu resource |

### S3 Policy cần 2 Statement riêng biệt

S3 phân biệt quyền ở **2 cấp độ**:

- **Bucket-level** (`arn:aws:s3:::bucket-name`) → `s3:ListBucket`, `s3:GetBucketLocation`
- **Object-level** (`arn:aws:s3:::bucket-name/*`) → `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`

Mỗi cấp cần resource ARN khác nhau nên phải tách ra 2 statement.

---

## 2. Lỗi: Variables not allowed

### Lỗi
```
Error: Variables not allowed
  on ec2-server.tf line 26, in variable "server_definitions":
  iam_instance_profile = aws_iam_instance_profile.jenkins.name
  Variables may not be used here.
```

### Nguyên nhân
Block `variable` chỉ chấp nhận **giá trị tĩnh** trong `default`. Không được tham chiếu resource vì:
- Terraform xử lý `variable` **trước tiên**, khi chưa có resource nào tồn tại
- `locals` xử lý **cùng lúc** với resource, nên có thể tham chiếu

### Cách sửa
Dùng string tĩnh thay vì resource reference:
```diff
- iam_instance_profile = aws_iam_instance_profile.jenkins.name
+ iam_instance_profile = "jenkins"
```

---

## 3. Lỗi: Duplicate resource name

### Lỗi
```
Error: Duplicate resource "aws_iam_role_policy_attachment" configuration
  A aws_iam_role_policy_attachment resource named "slave" was already declared
```

### Nguyên nhân
Hai resource `aws_iam_role_policy_attachment` cùng có tên `"slave"`. Terraform yêu cầu **tên duy nhất** trong cùng 1 resource type.

### Cách sửa
Đặt tên phân biệt theo pattern `{role}_{policy}`:
```diff
- resource "aws_iam_role_policy_attachment" "slave" {
+ resource "aws_iam_role_policy_attachment" "slave_ecr" {
    policy_arn = "...AmazonEC2ContainerRegistryFullAccess"
  }

- resource "aws_iam_role_policy_attachment" "slave" {
+ resource "aws_iam_role_policy_attachment" "slave_ssm" {
    policy_arn = "...AmazonSSMManagedInstanceCore"
  }
```

---

## 4. Lỗi: Reference to undeclared resource

### Lỗi
```
Error: Reference to undeclared resource
  role = aws_iam_role.server.name
  A managed resource "aws_iam_role" "server" has not been declared
```

### Nguyên nhân
Instance profile `jenkins` tham chiếu đến `aws_iam_role.server` (không tồn tại), thay vì `aws_iam_role.jenkins`.

### Cách sửa
```diff
resource "aws_iam_instance_profile" "jenkins" {
-  name = "server"
-  role = aws_iam_role.server.name
+  name = "jenkins"
+  role = aws_iam_role.jenkins.name
}
```

---

## 5. Lỗi: EC2 không nhận credentials sau khi recreate Instance Profile

### Triệu chứng
- `aws sts get-caller-identity` → `Unable to locate credentials`
- SSM Agent log: `ERROR EC2RoleProvider Failed to connect to Systems Manager, status code: 400`

### Nguyên nhân gốc
Khi Terraform **destroy rồi tạo lại** Instance Profile cùng tên, profile mới có **ID khác**. Nhưng EC2 vẫn giữ reference đến profile cũ (stale reference):

```
EC2 association trỏ đến:  ID: AIPA...GJESV (đã bị xóa)
Profile mới trên IAM:     ID: AIPA...QFSZ (chưa được gắn)
```

Terraform không phát hiện vì nó **so sánh theo tên** (cùng là "jenkins"), không so sánh ID.

### Cách sửa
Từ máy local, disassociate rồi associate lại:
```bash
# Gỡ profile cũ
aws ec2 disassociate-iam-instance-profile \
  --association-id <association-id>

# Gắn lại profile mới
aws ec2 associate-iam-instance-profile \
  --iam-instance-profile Name=jenkins \
  --instance-id i-048ab8ae097a393e9
```

### Bài học
- IAM Service và EC2 Service là **2 service độc lập**, không tự sync
- Tránh destroy + recreate Instance Profile đã gắn vào EC2
- Nếu cần đổi tên, dùng `terraform state mv` hoặc tạo đúng tên từ đầu

---

## 6. Lỗi: SSM TargetNotConnected

### Triệu chứng
```
An error occurred (TargetNotConnected) when calling the StartSession operation
```

### Nguyên nhân
SSM cần **3 điều kiện** để hoạt động:

| Điều kiện | Trạng thái |
|---|---|
| IAM Role có policy `AmazonSSMManagedInstanceCore` | ✅ |
| SSM Agent đang chạy trên EC2 | ❌ Cần restart sau khi gắn profile mới |
| EC2 có thể kết nối internet (outbound 443) | ✅ |

### Cách sửa
SSH vào EC2 và restart SSM Agent:
```bash
sudo systemctl restart amazon-ssm-agent
sudo systemctl status amazon-ssm-agent
```

### Kiểm tra IMDSv2
Amazon Linux 2023 mặc định dùng IMDSv2, cần token khi query metadata:
```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

---

## 7. Lỗi: Jenkins Agent service failed (systemd)

### Triệu chứng
```
WorkDirManager.initializeWorkDir → status=1/FAILURE
restart counter is at 61
```

### Nguyên nhân có thể
- Thư mục `workDir` chưa tồn tại hoặc sai quyền
- Secret key hoặc URL sai

### Cách debug
```bash
# Xem log chi tiết
sudo journalctl -u jenkins-agent -n 100 --no-pager -l

# Tìm nguyên nhân gốc
sudo journalctl -u jenkins-agent --no-pager | grep -i "caused by\|error\|exception" | tail -20

# Sửa quyền workDir
sudo mkdir -p /home/ec2-user/jenkins
sudo chown -R ec2-user:ec2-user /home/ec2-user/jenkins
```

---

## 8. Setup Jenkins JNLP Agent (thay thế SSH)

### Tại sao chuyển từ SSH sang JNLP?
- Không cần mở port 22 → an toàn hơn
- Slave **chủ động** kết nối đến Jenkins (không cần Jenkins reach được slave)
- Kết hợp tốt với SSM (bỏ SSH hoàn toàn)

### Ports cần thiết
| Port | Mục đích | Security Group |
|---|---|---|
| 8080 | Jenkins API (tải agent.jar, nhận lệnh) | Jenkins SG: ingress từ Slave SG |
| 50000 | JNLP communication channel | Jenkins SG: ingress từ Slave SG |

### Thay đổi Security Group
- ✅ Đã xóa port 22 (SSH) khỏi `ec2-server-sg` và `slave-sg`
- ✅ Đã tạo `jenkins-sg` riêng với port 8080 + 50000 từ slave

---

## Trạng thái hiện tại

### Files đã thay đổi
| File | Thay đổi |
|---|---|
| `iam-role.tf` | Tạo role + instance profile cho jenkins, sonarqube, grafana, slave |
| `ec2-server.tf` | Thêm `iam_instance_profile` field vào variable và resource |
| `network.tf` | Xóa SSH rules, thêm `jenkins-sg` với JNLP ports |
| `outputs.tf` | Thêm `iam_instance_profile` vào output |

### Đang làm
- [ ] Fix Jenkins Agent systemd service trên slave (lỗi `initializeWorkDir`)
- [ ] Cấu hình Jenkins UI tạo Node với launch method "Inbound Agent"
- [ ] Terraform apply các thay đổi Security Group mới
