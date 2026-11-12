# Shubham Bhardwaj — Portfolio

A static portfolio website served by Nginx in Docker. GitHub Actions builds an image, pushes it to Amazon ECR, and deploys it to a single EC2 instance through AWS Systems Manager (SSM).

## Run locally

Open `index.html` in a browser, or serve the project directory with any static file server.

## Run with Docker

```sh
docker build -t shubham-portfolio .
docker run --rm -p 8080:80 shubham-portfolio
```

Open `http://localhost:8080`.

## AWS deployment

Pushes to `main` run the deployment workflow in `.github/workflows/deploy.yml`:

1. Check the JavaScript syntax.
2. Build the Docker image and push a commit-SHA tag and `latest` to ECR.
3. Use GitHub Actions OIDC to request temporary AWS credentials.
4. Ask SSM to run `scripts/deploy-ec2.sh` on the target EC2 instance. The script pulls the image, smoke-tests it, replaces the running container, and restores the previous container if the new one fails its HTTP check.

### AWS prerequisites

1. Create an ECR repository (for example, `portfolio`) in the target Region.
2. Launch an Ubuntu or Amazon Linux EC2 instance. Install and start Docker, AWS CLI, `curl`, and the SSM Agent. Attach an instance profile with:
   - `AmazonSSMManagedInstanceCore`
   - `AmazonEC2ContainerRegistryReadOnly` (or an equivalent ECR pull policy limited to this repository)
3. Make sure the instance is online and managed by Systems Manager. Allow outbound HTTPS access to SSM and ECR. Allow inbound TCP port 80 from the intended visitors. SSH ingress is not required by this deployment workflow.
4. In IAM, configure the GitHub OIDC provider `token.actions.githubusercontent.com` with audience `sts.amazonaws.com`. Create a role whose trust policy is restricted to this repository's `main` branch. Replace `<ACCOUNT_ID>`, `<OWNER>`, `<REPOSITORY>`, and `<REGION>` below:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
           "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPOSITORY>:ref:refs/heads/main"
         }
       }
     }]
   }
   ```

5. Grant that role permission to push to the ECR repository and invoke SSM on the target instance. The following is a starting point for an inline permissions policy; replace the same placeholders:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "ecr:GetAuthorizationToken",
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "ecr:BatchCheckLayerAvailability",
           "ecr:BatchGetImage",
           "ecr:CompleteLayerUpload",
           "ecr:InitiateLayerUpload",
           "ecr:PutImage",
           "ecr:UploadLayerPart"
         ],
         "Resource": "arn:aws:ecr:<REGION>:<ACCOUNT_ID>:repository/portfolio"
       },
       {
         "Effect": "Allow",
         "Action": "ssm:SendCommand",
         "Resource": [
           "arn:aws:ssm:<REGION>::document/AWS-RunShellScript",
           "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/<INSTANCE_ID>"
         ]
       },
       {
         "Effect": "Allow",
         "Action": "ssm:GetCommandInvocation",
         "Resource": "*"
       }
     ]
   }
   ```

6. Add these **Actions repository variables** under **Settings → Secrets and variables → Actions → Variables**:

   | Variable | Value |
   | --- | --- |
   | `AWS_REGION` | AWS Region containing the ECR repository and EC2 instance |
   | `AWS_ROLE_TO_ASSUME` | ARN of the GitHub OIDC deployment role |
   | `ECR_REPOSITORY` | ECR repository name, such as `portfolio` |
   | `EC2_INSTANCE_ID` | Instance ID of the SSM-managed EC2 instance |

Push to `main` to deploy. You can also start the workflow manually from the `main` branch in the GitHub Actions tab.

### Deployment notes

- The workflow does not store long-lived AWS access keys in GitHub.
- The EC2 instance must have outbound connectivity to ECR and SSM, and its instance profile must be able to pull from the repository.
- This setup serves HTTP on port 80 from one EC2 instance. A replacement causes a brief interruption. For public production traffic, place an HTTPS load balancer (or another TLS-terminating front end) in front of the instance and plan for high availability separately.
