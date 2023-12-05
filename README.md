## Data transformation with lambda function and S3 buckets using Terraform

![tf_aws](https://github.com/davidrochabio/terraform_aws_lambda_s3/assets/62852893/d4ca4942-0020-4444-a2df-b27bf9924c68)

### Prerequisites
- An AWS account
- AWS CLI configured with your AWS credentials
- Terraform installed on your local machine

-> Tip: Use docker to create lambda function custom layers. This [article](https://medium.com/simform-engineering/creating-lambda-layers-made-easy-with-docker-a-developers-guide-3bcfcf32d7c3) is a good reference.

The requirements for the layer are inside the 'layer_requirements.txt' file.
The layer should be placed in the same directory as 'main.tf' file and should be named as 'pandasrequests_layer.zip'. 

### Data and Goal
The data contains information about bank accounts. The bank supports accounts in different currencies.
-> The goal is to clean the data and transform ammounts in different currencies to a common currency - like canadian dollars in this example.

The function makes use of a currency converstion rate API to dinnamicaly get the rates for each of the unique currencies in the dataset.

[API reference](https://www.exchangerate-api.com/docs/free)

### Lambda Function
The function listens to an S3 bucket for new files.
When a new file is added to the bucket, the Lambda function checks if the file name is 'banking_dirty.csv'.
If the name matches, the function reads the file from bucket and performs the following operations:
- Normalizes column names to lower case.
- Normalizes the date columns to desired format.
- Adds a column with the exchange rate for each account and respective account currency.
- Adds a column with the account amount converted to the desired common currency.
- Adds a column with the load date and time.
- Writes the cleaned data to another S3 bucket.

### Terraform and AWS 
Terraform creates the following infrastructure in AWS:
- Two s3 buckets
- lambda function layer with pandas and requests
- lambda function
- lambda function role and security policies
- trigger from s3
- notification
