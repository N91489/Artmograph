# AWS Infrastructure Setup Guide

## Overview

This guide provides two methods to provision AWS infrastructure for your application: automated deployment using Terraform or manual setup through the AWS Console. The infrastructure includes networking, security, compute resources, and persistent IP addressing.

## Infrastructure Components

The following resources will be created:

- **VPC**: Default VPC (created if not already present)
- **SSH Key Pair**: RSA 4096-bit key for secure instance access
- **Security Group**: Configured with the following inbound rules:
  - SSH (Port 22)
  - HTTP (Port 80)
  - HTTPS (Port 443)
  - MQTT (Port 1883)
- **EC2 Instance**:
  - Instance Type: g4dn.xlarge with NVIDIA T4 GPU (default)
  - Storage: 100GB EBS volume
  - Region: Mumbai (ap-south-1)
  - Operating System: Debian
- **Elastic IP**: Static public IP address for consistent access

## Method 1: Automated Deployment with Terraform

### Prerequisites

1. **Install AWS CLI**
   
   Follow the official installation guide:
   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

2. **Configure AWS Credentials**
   
   Set up your AWS access credentials:
   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html
   
   Note: Ensure your IAM user has appropriate EC2 and VPC permissions.

3. **Install Terraform**
   
   Download and install from:
   https://www.terraform.io/downloads.html

### Deployment Steps

Navigate to the terraform directory in your terminal before proceeding.

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Review the Deployment Plan**
   ```bash
   terraform plan
   ```

3. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```
   Confirm by typing `yes` when prompted.

### Handling Common Deployment Issues

**Instance Capacity Error**

If you encounter an error such as:
- `InsufficientInstanceCapacity: We currently do not have sufficient g4dn.xlarge capacity`
- `UnauthorizedOperation: Your account is not authorized to use the specified instance type`

Resolution: Modify the instance type in `main.tf`:
```hcl
instance_type = "t3.small"
```
Then redeploy:
```bash
terraform apply
```

### Accessing Your Instance

After successful deployment, Terraform will display:
```
instance_static_ip = "X.X.X.X"
```

Connect via SSH:
```bash
chmod 600 artmograph.pem
ssh -i artmograph.pem ec2-user@<instance_static_ip>
```

### Resource Cleanup

To avoid ongoing charges, destroy all resources when finished:
```bash
terraform destroy
```

## Method 2: Manual Setup via AWS Console

### Step 1: Create SSH Key Pair

1. Navigate to **EC2 Console** > **Key Pairs**
2. Click **Create Key Pair**
3. Configure:
   - Name: `artmograph-key`
   - Key pair type: `RSA`
   - Private key file format: `.pem`
4. Click **Create Key Pair**

The private key file will download automatically. Secure it immediately:
```bash
chmod 600 artmograph-key.pem
```

### Step 2: Configure Security Group

1. Navigate to **EC2 Console** > **Security Groups** > **Create security group**
2. Basic Configuration:
   - Name: `artmograph-security-group`
   - Description: `Allow SSH, HTTP, HTTPS, MQTT`
   - VPC: Select your default VPC

3. Configure Inbound Rules:

   | Type        | Protocol | Port | Source    | Description           |
   |-------------|----------|------|-----------|----------------------|
   | SSH         | TCP      | 22   | 0.0.0.0/0 | Remote access        |
   | HTTP        | TCP      | 80   | 0.0.0.0/0 | Web traffic          |
   | HTTPS       | TCP      | 443  | 0.0.0.0/0 | Secure web traffic   |
   | Custom TCP  | TCP      | 1883 | 0.0.0.0/0 | MQTT protocol        |

   Note: For production environments, restrict SSH source to your specific IP address.

4. Leave Outbound rules as default (All traffic allowed)
5. Click **Create security group**

### Step 3: Launch EC2 Instance

1. Navigate to **EC2 Console** > **Instances** > **Launch Instance**
2. Configure instance settings:
   - **Name**: `Artmograph-Server`
   - **AMI**: Select Debian
   - **Instance Type**: `g4dn.xlarge` (or `t3.small` if GPU instances are unavailable)
   - **Key Pair**: Select `artmograph-key`
   - **Network Settings**: 
     - VPC: Default VPC
     - Security Group: `artmograph-security-group`
   - **Storage**: 100 GB gp3 volume (adjust as needed, minimum 45 GB recommended)
3. Click **Launch Instance**

### Step 4: Configure Static IP Address

1. Navigate to **EC2 Console** > **Elastic IPs** > **Allocate Elastic IP**
2. Click **Allocate**
3. Select the allocated IP > **Actions** > **Associate Elastic IP**
4. Select your instance (`Artmograph-Server`) and click **Associate**

### Step 5: Connect to Your Instance

```bash
chmod 600 artmograph-key.pem
ssh -i artmograph-key.pem admin@<your-elastic-ip>
```

Note: The username may vary by AMI (typically `admin` for Debian, `ec2-user` for Amazon Linux).

### Manual Resource Cleanup

When finished with your resources:
1. Terminate the EC2 instance
2. Release the Elastic IP address to stop incurring charges

## Best Practices

- **Security**: Always restrict SSH access to known IP addresses in production environments
- **Cost Management**: Stop or terminate instances when not in use
- **Backup**: Regularly backup your data and configuration
- **Monitoring**: Enable CloudWatch monitoring for production workloads
- **Key Management**: Store SSH keys securely and never commit them to version control

## Troubleshooting

### Connection Issues
- Verify security group rules allow your IP address
- Ensure the instance is in a running state
- Check that you're using the correct SSH key and username

### Performance Considerations
- GPU instances (g4dn.xlarge) provide better performance for compute-intensive workloads
- T3 instances are suitable for general-purpose workloads with burstable performance
- Consider your workload requirements when selecting instance types

## Additional Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Pricing Calculator](https://calculator.aws.amazon.com/)
