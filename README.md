# iris-aws-localstack-demo
 Demo LocalStack for S3

## Install
Clone this repository

```
git clone https://github.com/LEADNorthLLC/iris-aws-localstack-demo.git
```

Docker

```
docker-compose up --build -d
```

## Usage
Once Docker starts without issue, then reach the Management Portal with this address: 

User: _system Pass: SYS

[Management Portal](http://localhost:45451/csp/sys/UtilHome.csp)


## IRIS Terminal
Access Terminal by entering the following in Docker terminal or Bash terminal. Iris is automaticallly logged in.
```bash
docker exec -it [Docker Container Name]-[Iris container name] bash
iris terminal IRIS
```

example: 
```bash
docker exec -it iris-aws-localstack-demo-iris-1 bash
iris terminal IRIS
```

## Run commands
Run the following commands within the iris terminal to interact with the bucket programmatically

**Create bucket** 
Do ##class(DQS.CloudUtils.S3.S3UUtil).CreateBucket("yourBucket")
**Get bucket** 
Do ##class(S3.S3UUtil).GetBucket("yourBucket", "yourObjectKey")
**Put objects in bucket**
Do ##class(S3.S3UUtil).PutObject("yourBucket", "yourObjectKey")
**Pull objects from bucket** 
Do ##class(DQS.CloudUtils.S3.S3UUtil).PullObjectFromBucket("yourBucket", "yourObjectKey")
