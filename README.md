# TaskFlow: A Cloud-Hosted Task Manager on AWS

TaskFlow is a task management web app that I deployed on AWS using Terraform, Docker, Amazon ECR and GitHub Actions. You can add tasks, tick them off and delete them. The app is deliberately simple. The point of the project is the cloud infrastructure around it, which is written entirely as code so the whole environment can be created or destroyed with one command.

I also ran the same app on a local Kubernetes cluster to learn how the same three tiers work there (see the Kubernetes section below).

## Technologies Used

| Area | Tools |
| --- | --- |
| AWS | VPC, EC2, Application Load Balancer, Auto Scaling, RDS, ECR, IAM, Secrets Manager, S3, CloudWatch |
| Infrastructure as Code | Terraform (S3 remote state with locking) |
| Containers | Docker, Amazon ECR |
| Backend | Python, Flask, SQLAlchemy, Gunicorn |
| Frontend | HTML, CSS, JavaScript |
| Database | PostgreSQL 16 |
| CI/CD | GitHub Actions with OIDC (no stored AWS keys) |
| Local Kubernetes | minikube, kubectl |

## Project Structure

```text
taskflow-terraform-aws/
  .github/workflows/deploy.yml    CI/CD pipeline
  app/
    app.py                        Flask backend and API
    Dockerfile                    container image
    requirements.txt              Python packages
    templates/index.html          page markup
    static/app.js, style.css      frontend code and styling
  terraform/
    main.tf                       providers and S3 backend
    vpc.tf, routing.tf            network, subnets, routes
    security.tf                   security groups
    storage.tf, iam.tf            S3 bucket, IAM role and policies
    database.tf                   RDS, generated password, secret
    compute.tf, user_data.sh.tftpl   launch template and boot script
    alb.tf, asg.tf                load balancer and auto scaling
    monitoring.tf                 CloudWatch alarms
    ecr.tf                        container registry
    github.tf                     OIDC provider and deploy role
    outputs.tf                    values printed after apply
  k8s/
    taskflow.yaml                 Kubernetes Deployment and Service
    postgres.yaml                 PostgreSQL Deployment and Service
```

## What I Built

### 1. Network and security with Terraform

A VPC with two public and two private subnets across two availability zones, an internet gateway and route tables. Three security groups restrict traffic so each tier only talks to the one next to it. The instances use IMDSv2 and are managed through Session Manager, so no SSH port is open.

### 2. Docker and Amazon ECR

The app is packaged as a Docker image served by Gunicorn and stored in a private ECR repository. The repository scans images on push and keeps only the last five images.

### 3. Load balancing and auto scaling

An Application Load Balancer checks the /health endpoint and sends traffic to EC2 instances in an Auto Scaling Group. The group keeps between 2 and 4 instances and scales to hold average CPU near 60 percent. New instances boot with a script that installs Docker, logs in to ECR, pulls the image and starts the container.

### 4. Database and secrets

PostgreSQL runs on RDS in private subnets and is not publicly accessible. Terraform generates the password and stores the connection details in AWS Secrets Manager. The application reads the secret at startup, and the instance role may read only that one secret, so no password appears in code or in Git.

### 5. CI/CD with GitHub Actions

Every push to main builds the Docker image, pushes it to ECR tagged with both latest and the commit SHA, and starts an instance refresh so the Auto Scaling Group replaces its servers with the new image. The workflow logs in to AWS with OIDC and a short-lived role, so there are no access keys stored in GitHub.

### 6. Monitoring

CloudWatch alarms watch for unhealthy targets behind the load balancer and for sustained high CPU on the Auto Scaling Group.

## Deploying It

Requirements: an AWS account, Terraform 1.10 or newer, Docker and the AWS CLI configured.

1. Create an S3 bucket by hand for Terraform state (Terraform cannot store its state in a bucket it has not created yet). Its name goes in terraform/main.tf. S3 bucket names are global, so the names in the code must be changed to your own.

2. Create the container registry first, because servers pull the image when they boot:

```bash
cd terraform
terraform init
terraform apply -target=aws_ecr_repository.app
```

3. Build and push the first image:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker build -t taskflow:latest ../app
docker tag taskflow:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskflow:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/taskflow:latest
```

4. Build everything else:

```bash
terraform apply
terraform output app_url
```

Open the app_url in a browser. RDS takes several minutes to create.

5. To remove everything and stop all charges:

```bash
terraform destroy
```

The hand-made state bucket is not part of the project and stays.

The GitHub OIDC trust policy in terraform/github.tf names my repository. If you fork the project, change it to yours.

## Running TaskFlow on Kubernetes (local)

After building the AWS version, I ran TaskFlow on a local Kubernetes cluster (minikube) to learn how the same three tiers work there. It runs on my own computer, not on AWS, so it costs nothing. The manifests are in the k8s folder.

| AWS version | Kubernetes version |
| --- | --- |
| Auto Scaling Group with 2 servers | Deployment with 2 Pods |
| Application Load Balancer | Service |
| ALB health check on /health | readinessProbe on /health |
| RDS PostgreSQL | PostgreSQL Pod and Service |
| Secrets Manager | Kubernetes Secret |
| Instance refresh | Rolling update |

taskflow.yaml defines the app Deployment and Service. postgres.yaml defines the database. The database password is created with a command, so it is never stored in a file or in Git, and the app reads it through a secretKeyRef.

To run it:

```bash
minikube start --driver=docker
docker tag taskflow:latest taskflow:local
minikube image load taskflow:local
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD=choose-a-practice-password \
  --from-literal=POSTGRES_DB=taskflow \
  --from-literal=POSTGRES_USER=taskflow
kubectl apply -f k8s/
kubectl port-forward service/taskflow 8081:80
```

Then open http://localhost:8081. Use your own password in place of the practice one.

What I learned:

- With SQLite, every Pod kept its own data, so two Pods showed different tasks. Giving all Pods one PostgreSQL database fixed it, and the tasks survive when the app Pods are deleted.
- The PostgreSQL Pod has no persistent volume, so its data is lost if that Pod is deleted. A real cluster would use a volume or RDS.
- I diagnosed a missing DATABASE_URL by checking the variable inside the Pod with kubectl exec. The update had never been applied because kubectl apply was run from the wrong folder.
- I practised rolling updates and rollbacks, ConfigMaps and Secrets, and troubleshooting with kubectl describe and kubectl logs.

## Challenges and Lessons Learned

1. Database connection configuration. The app first failed to connect because of the wrong SQLAlchemy dialect. Using postgresql+psycopg2 in the connection string fixed it.

2. Concurrent database initialization. Several instances tried to create the table at the same moment on first boot. The logs showed the race, and I made the initialization tolerate it.

3. Launch template updates. Changing a launch template does not alter running instances. An instance refresh replaces them, so I added one to the pipeline.

4. GitHub Actions OIDC authentication. The pipeline failed with a role-assumption error. I printed the OIDC subject claim and found that GitHub now includes numeric owner and repository IDs, so I updated the trust policy to accept it.

5. Order of creation. Servers pull their image from ECR at boot, so the registry and an image have to exist before the Auto Scaling Group. I created the registry first with terraform apply -target.

6. Reading Terraform plans. Reviewing a plan before every apply made it clear which changes were updates and which were replacements or deletions. I also learned that a data source is read, not created, so it does not count as a resource in the plan.

7. Verifying instead of assuming. In Kubernetes the web page could not tell me which database was in use. Checking inside the Pod found the real cause.

## Future Improvements

- Add HTTPS. The load balancer currently serves HTTP only. I plan to add a domain in Route 53, an ACM certificate and an HTTPS listener.
- Tighten the network. The app servers sit in public subnets, protected by security groups that only allow traffic from the load balancer. A stricter design would place them in private subnets behind a NAT gateway.
- Make the database highly available. RDS runs in a single availability zone to keep the cost low while learning. Enabling Multi-AZ would add automatic failover.

## Author

Adenuga Oluwaferanmi, Cloud Engineer

- GitHub: https://github.com/adenugaferanmi58-cloud
- Related project: TaskFlow Serverless, the same task app built with Lambda, API Gateway, DynamoDB, S3 and CloudFront