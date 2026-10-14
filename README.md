#  TaskFlow — AWS Project

A containerized task management application deployed on AWS using Terraform, Docker, Amazon ECR, and GitHub Actions CI/CD.

TaskFlow demonstrates how to provision cloud infrastructure, deploy a Flask application, manage secrets securely, and automate application updates using Infrastructure as Code and continuous deployment.

## 🏗️ Architecture

   text
                    ┌──────────────────┐
                    │      Client      │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Application Load │
                    │    Balancer      │
                    └────────┬─────────┘
                             │
                  ┌──────────▼──────────┐
                  │  Auto Scaling Group │
                  │                     │
                  │  EC2 + Docker       │
                  │  TaskFlow App       │
                  └──────────┬──────────┘
                             │
                    ┌────────▼─────────┐
                    │  Amazon RDS      │
                    │  PostgreSQL      │
                    └──────────────────┘

       CI/CD: GitHub Actions → Amazon ECR → EC2
       Infrastructure: Terraform
       Secrets: AWS Secrets Manager
       Monitoring: Amazon CloudWatch
```
# TaskFlow 

### A Cloud-Hosted Task Management Application

## About the Project

## Technologies Used

* **AWS:** EC2, Application Load Balancer, Auto Scaling, RDS, ECR, IAM, Secrets Manager, CloudWatch
* **Infrastructure as Code:** Terraform
* **Containerization:** Docker
* **Backend:** Python, Flask, SQLAlchemy, Gunicorn
* **Database:** PostgreSQL
* **CI/CD:** GitHub Actions
* **Security:** GitHub Actions OIDC and IAM roles

## What I Built

### 1. AWS Infrastructure with Terraform

I used Terraform to provision and manage the AWS resources required to run the application.

### 2. Docker Containerization

I packaged the application into a Docker image and stored it in Amazon ECR.

### 3. Load Balancing and Auto Scaling

I configured an Application Load Balancer to route traffic to EC2 instances managed by an Auto Scaling Group.

### 4. Database and Secrets Management

I integrated the application with Amazon RDS PostgreSQL and used AWS Secrets Manager to manage database credentials.

### 5. CI/CD Automation

I configured GitHub Actions to build the Docker image, push it to Amazon ECR, and support application deployment updates.

### 6. Monitoring

I configured CloudWatch alarms to monitor selected AWS infrastructure metrics.

## Challenges and Lessons Learned

1. Database Connection Configuration

The application initially failed to connect because of an incorrect SQLAlchemy database dialect. Correcting the connection string to use postgresql+psycopg2 resolved the issue.

2. Concurrent Database Initialization

Multiple application instances attempted to initialize the database simultaneously. Investigating the logs helped identify the race condition and improve initialization handling.

3. Launch Template Updates

Updating an EC2 launch template does not automatically change the configuration of existing instances. An instance refresh can roll out the updated configuration.

4. GitHub Actions OIDC Authentication

The deployment pipeline encountered an AWS role-assumption error. Investigating the GitHub OIDC subject claim helped identify the trust-policy mismatch and guide the correction.

5. Terraform Infrastructure Management

Terraform made it possible to define and review infrastructure changes before applying them. Reviewing plans helped distinguish infrastructure updates from resource destruction.

## Conclusion

Building TaskFlow gave me practical experience deploying and managing a cloud-hosted application on AWS.

This project strengthened my understanding of cloud infrastructure, automation, containerization, and deployment workflows.
 
 ## Author

**Adenuga Oluwaferanmi**
Cloud Engineer

* GitHub: [adenugaferanmi58-cloud](https://github.com/adenugaferanmi58-cloud)
* Project: TaskFlow — AWS Cloud Deployment with Terraform, Docker, and GitHub Actions
CI/CD: Automated deployment using GitHub Actions, Docker, Amazon ECR, and AWS Auto Scaling.