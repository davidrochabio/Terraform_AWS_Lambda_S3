## Data transformation with lambda function and S3 buckets using Terraform

![Archit](https://github.com/davidrochabio/Terraform_AWS_Lambda_S3/assets/62852893/8bf2b2fc-1b33-4ac6-80d8-41fea08f9800)

### Prerequisites
- An AWS account
- AWS CLI configured with your AWS credentials
- Terraform installed on your local machine
- Docker to create lambda layer. You can do it without Docker, check [AWS docs](https://docs.aws.amazon.com/lambda/latest/dg/chapter-layers.html).

The requirements for the layer are inside the 'layer_requirements.txt' file.
The layer should be placed in the same directory as 'main.tf' file and should be named 'pandasrequests_layer.zip'. 

### Data and Goal
The data contains information about bank accounts. The bank supports accounts in different currencies.
-> The goal is to clean the data and transform ammounts in different currencies to a common currency - canadian dollar in this example.

The function makes use of a currency convertion rate API to dinamically get the rates for the unique currencies present in the dataset.

[API reference](https://www.exchangerate-api.com/docs/free)

### Lambda Function
The function listens to an S3 bucket for new files.
When a new file is added to the bucket, the bucket triggers the lambda function. 
The Lambda function checks if the file name is 'banking_dirty.csv'.
If the name matches, the function reads the file from the bucket and performs the following operations:
- Normalizes column names to lower case.
- Normalizes the date columns to the desired format.
- Adds a column with the exchange rate for each account.
- Adds a column with the account amount converted to the desired common currency.
- Adds a column with the load date and time.
- Writes the transformed dataframe to another S3 bucket in csv format.

### Terraform and AWS 
Terraform creates the following infrastructure in AWS:
- Two s3 buckets
- lambda function (Python 3.11)
- lambda function layer version with pandas and requests 
- lambda function role and security policies
- trigger from s3
- notification

### Usage
- Clone repo and enter repo folder:
```
git clone https://github.com/davidrochabio/Terraform_AWS_Lambda_S3.git

cd Terraform_AWS_Lambda_S3
```

- Create lambda layer with pandas and requests using docker and provided dockerfile:
```
docker build -t layer_image -f ./Dockerfile-layer .

docker run -dit --name layer_container layer_image /bin/bash

docker cp layer_container:/app/pandasrequests_layer.zip .

docker rm -f layer_container

docker rmi layer_image
```

- Initialize Terraform:
```
terraform init
```

- Validate main.tf and check plan:
```
terraform validate

terraform plan
```

- Create resources in AWS:
```
terraform apply
```
PS: Terraform might throw an error if bucket names are already used in AWS. If that's the case, change bucket names in main.tf and in the lambda function.
- Send file to s3 bucket
```
aws s3 cp ./banking_dirty.csv s3://input-banking-dirty/banking_dirty.csv
```

- Check CloudWatch logs to see execution.

#### To destroy resources
- Empty s3 buckets:
```
aws s3 rm s3://output-banking-clean --recursive
aws s3 rm s3://input-banking-dirty --recursive
```

- Destroy resources:
```
terraform destroy
```
