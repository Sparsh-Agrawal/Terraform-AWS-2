provider "aws" {
  version = "~> 2.65"
  region  = "us-east-1"
  profile = "sparsh"
}

resource "tls_private_key" "private-key" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_key_pair" "infra2108-key" {
    key_name   = "infra2108-key"
    public_key = tls_private_key.private-key.public_key_openssh
}

resource "aws_security_group" "infra2108-sg" {
  name        = "infra2108-sg"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "infra2108-sg"
  }
}

resource "aws_instance" "infra2108-instance" {
  ami               = "ami-09d95fab7fff3776c"
  instance_type     = "t2.micro"
  key_name          = "${aws_key_pair.infra2108-key.key_name}"
  security_groups   = ["infra2108-sg"]
  availability_zone = "us-east-1a"
  user_data         = <<-EOF
		#! /bin/bash
    sudo yum update -y
		sudo yum install httpd -y
		sudo systemctl start httpd
		sudo systemctl enable httpd
		sudo yum install git -y
	EOF

  tags = {
    Name = "infra2108-instance"
  }
}

output "instancePublicIP" {
  value = "${aws_instance.infra2108-instance.public_ip}"
}

resource "aws_efs_file_system" "infra2108-efs" {
  creation_token = "t2efs"
  performance_mode = "generalPurpose"

  tags = {
    Name = "infra2108-efs"
  }
}

resource "aws_efs_mount_target" "infra2108-efs-mount" {
  file_system_id = "${aws_efs_file_system.infra2108-efs.id}"
  subnet_id = "${aws_instance.infra2108-instance.subnet_id}"
}

resource "null_resource" "mount_efs_volume" {
  depends_on = [aws_efs_mount_target.infra2108-efs-mount]  

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.private-key.private_key_pem
    host     = aws_instance.infra2108-instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html/",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Sparsh-Agrawal/Terraform-AWS-2.git ."
      ]  
  }
}

resource "aws_s3_bucket" "infra2108-s3" {
  bucket = "infra2108-s3"
  force_destroy = true
}


resource "aws_s3_bucket_policy" "infra2108-s3" {
  bucket = "${aws_s3_bucket.infra2108-s3.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
    "Id": "Policy1591793565800",
    "Statement": [
        {
            "Sid": "Stmt1591793552657",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::infra2108-s3/*"
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_object" "infra2108-bucket-object" {
  bucket = "${aws_s3_bucket.infra2108-s3.id}"
  key = "terraws.png"
  source = "image/terraws.png"
  acl = "public-read"
  etag = filemd5("image/terraws.png")
  depends_on = [aws_s3_bucket.infra2108-s3]
}


locals {
  s3_origin_id = "task2S3Origin"
}


resource "aws_cloudfront_distribution" "infra2108-cloudfront" {
  origin {
    domain_name = "${aws_s3_bucket.infra2108-s3.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/E2S08P3MENZA9K"
    }
  }

  enabled             = true
  comment             = "Task 2"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["DE","CA"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }


  provisioner "remote-exec" {
    inline = [
      "sudo su <<EOF",
      "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.infra2108-bucket-object.key}' height='400' width='400'></center>\" >>/var/www/html/index.html",
      "EOF"
    ]
  }

  provisioner "local-exec" {
    command = "start chrome ${aws_instance.infra2108-instance.public_ip}"
  }

}
