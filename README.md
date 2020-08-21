![](images/terraws.png)
# Terraform-AWS-2
Terraform is an open-source tool created by **HashiCorp**. It is used for building, changing, and versioning infrastructure safely and efficiently. Terraform can manage existing and popular service providers as well as custom in-house solutions. </br></br>
Here I have created a infrastructure in **HCL (Hashicorp Configuration Language)** which consists of 
<br/>
* Create a Key to log in to the EC2 instance or to connect to it via SSH to run commands.
![](images/privatekey.png)

* Create a security group for the instance, and provide inbound and outbound rules.
![](images/securitygroup.png)

* Create an AWS instance, using Amazon Linux 2 AMI (HVM)
![](images/instance.png)

*  Launch one Volume using the EFS service and attach EFS to VPC and Instance.
![](images/efs.png)

* Mount the EFS to /var/www/html directory so that all the files are permanently stored in EFS.
![](images/cmd.png)

* Create an S3 bucket. Setting permissions to Public so that it's publically accessible.
![](images/s3.png)

* Create a CDN using AWS CloudFront for S3 Bucket. Setup the cache precedence. Put restrictions based on the requirements. And add the cloud-front URL in the WebPage.
![](images/cf1.png)
![](images/cf2.png)
![](images/cf3.png)

* Launch the webpage on the CHROME using Instance Public_IP.
![](images/chrome.png)
