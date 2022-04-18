# aws-toolbox

Docker Toolbox to work with AWS Services.

User `make install` to create the Docker container and the following command to run it:

```bash
docker run -it -w /app -v $(pwd):/app -v ~/.aws:/root/.aws -v /var/run/docker.sock:/var/run/docker.sock -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN -e AWS_DEFAULT_REGION -e
AWS_PROFILE -e AWS_CONFIG_FILE -e AWSINFO_DEBUG theserverlessway/aws-toolbox
```