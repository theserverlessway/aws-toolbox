CURRENT_WORKSPACE=$(shell terraform workspace  list | sed -n "s/^* \(\S*\)/\1/p")

toolbox-rebuild:
	docker-compose -f toolbox/docker-compose.yaml build --no-cache

release:
	docker buildx build --push --platform=linux/amd64 -t theserverlessway/aws-toolbox .

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR=$(notdir $(CURDIR))

CONTAINER_PREFIX=toolbox-$(CURRENT_DIR)

CONTAINER_ID=$(shell docker ps | grep $(CONTAINER_PREFIX) | awk '{print $$1}')

current-dir:
	echo $(CURRENT_DIR)

toolbox:
	touch toolbox/bash_history
	if [[ -z "$(CONTAINER_ID)" ]]; then docker-compose -f toolbox/docker-compose.yaml build && docker-compose -f toolbox/docker-compose.yaml run --rm --name $(CONTAINER_PREFIX)-$$RANDOM toolbox bash; else docker exec -it $(CONTAINER_ID) bash;  fi

# ECS TASKS

workspace:
	@echo $(CURRENT_WORKSPACE)

tasks-running:
	awsinfo  ecs tasks shared -- $(CURRENT_WORKSPACE)

tasks-stopped:
	awsinfo  ecs tasks -s shared -- $(CURRENT_WORKSPACE)

tasks: tasks-running tasks-stopped

HOURS=2

failing-tasks-events:
	@QUERY_ID=$$(aws logs start-query --log-group-name "/terraform/shared-services/ecs/shared-services-cluster/events" --start-time $$(date --date -$(HOURS)hours "+%s") --end-time $$(date "+%s") --query-string 'field @timestamp, detail.stopCode as StopCode, substr(detail.stoppedReason,0,40) as StoppedReason, substr(detail.containers.0.reason,0,40) as ContainerReason, substr(detail.taskDefinitionArn,38) as TaskDefinition, substr(detail.taskArn,38) as TaskARN  | filter (detail.lastStatus = "STOPPED") | filter (detail.stoppedReason not like "Scaling activity initiated by")' --query queryId --output text) && \
	echo QueryId: $$QUERY_ID && \
	while [ $$(aws logs get-query-results --query-id "$$QUERY_ID" --query status --output text) != "Complete" ]; do (echo -n "." && sleep 2) done && \
	aws logs get-query-results  --query-id $$QUERY_ID --query "results[*].{\"1.Timestamp UTC\":@[?field=='@timestamp'].value|@[0],\"2.Code\":@[?field=='StopCode'].value|@[0],\"3.Reason\":@[?field=='StoppedReason'].value|@[0],\"4.ContainerReason\":@[?field=='ContainerReason'].value|@[0],\"5.TaskDefinition\":@[?field=='TaskDefinition'].value|@[0],\"6.Task\":@[?field=='TaskARN'].value|@[0]}" --output table

failing-aws-api-requests:
	@QUERY_ID=$$(aws logs start-query --log-group-name "CloudTrail/Landing-Zone-Logs" --start-time $$(date --date -$(HOURS)hours "+%s") --end-time $$(date "+%s") --query-string 'field eventTime, errorCode, concat(replace(eventSource,".amazonaws.com",""),":",eventName) as event, awsRegion, substr(errorMessage,0,40) as message, userIdentity.arn as arn | filter (errorCode like "UnauthorizedOperation" or errorCode like "AccessDenied" )' --query queryId --output text) && \
	echo QueryId: $$QUERY_ID && \
	while [ $$(aws logs get-query-results --query-id "$$QUERY_ID" --query status --output text) != "Complete" ]; do (echo -n "." && sleep 2) done && \
	aws logs get-query-results  --query-id $$QUERY_ID --output table --query "results[*].{\"1.EventTime\":@[?field=='eventTime'].value|@[0],\"2.ErrorCode\":@[?field=='errorCode'].value|@[0],\"3.Event\":@[?field=='event'].value|@[0],\"5.AwsRegion\":@[?field=='awsRegion'].value|@[0],\"6.Message\":@[?field=='message'].value|@[0],\"7.SessionArn\":@[?field=='arn'].value|@[0]}"

tasks-running-all:
	awsinfo  ecs tasks shared

tasks-stopped-all:
	awsinfo  ecs tasks -s shared

tasks-all: tasks-running-all tasks-stopped-all

tasks-watch:
	watch -n 5 -c "awsinfo  ecs tasks shared -- $(CURRENT_WORKSPACE) && awsinfo  ecs tasks -s shared -- $(CURRENT_WORKSPACE)"

tasks-watch-filtered:
ifndef TASK_FILTER
	$(error TASK_FILTER is not set)
endif
	watch -n 5 -c "awsinfo  ecs tasks shared -- $(CURRENT_WORKSPACE) $(TASK_FILTER) && awsinfo  ecs tasks -s shared -- $(CURRENT_WORKSPACE) $(TASK_FILTER)"

tasks-watch-all:
	watch -n 5 -c "awsinfo  ecs tasks shared && awsinfo ecs tasks -s shared"

# ECS SERVICES

ECS_SERVICES_ALL = aws ecs list-services --output text --cluster shared-services-cluster --query "serviceArns[].[@]" | sort

ECS_SERVICES_CLI = aws ecs list-services --output text --cluster shared-services-cluster --query "serviceArns[?contains(to_string(@),'$(CURRENT_WORKSPACE)')].[@]" | sort

services:
	$(ECS_SERVICES_CLI)

services-all:
	$(ECS_SERVICES_ALL)

#Deployments

DEPLOYMENTS = xargs -n 10 aws ecs describe-services --cluster shared-services-cluster --output table --query "sort_by(services,&serviceName)[].{\"1.Name\":serviceName,\"2.STATUS\":deployments[?status=='PRIMARY']|[0].rolloutState,\"3.Deployment Count\":length(deployments),\"4 Primary.Desired\":deployments[?status=='PRIMARY']|[0].desiredCount,\"5.Primary Pending\":deployments[?status=='PRIMARY']|[0].pendingCount,\"6.Primary Running\":deployments[?status=='PRIMARY']|[0].runningCount}" --services

deployments-all:
	@$(ECS_SERVICES_ALL) | $(DEPLOYMENTS)

deployments:
	@$(ECS_SERVICES_CLI) | $(DEPLOYMENTS)

# ECS SCALING

SCALE_TARGETS = terraform show -json | jq '.. | select(.name == "ecs-as-target")? | .values.id' -r | sort
SCALE_COMMAND = $(SCALE_TARGETS) | xargs -n 1 aws application-autoscaling register-scalable-target --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --min-capacity $1 --max-capacity $2 --resource-id

scale-up-all:
	$(call SCALE_COMMAND,1,2)

scale-down-all:
	$(call SCALE_COMMAND,0,0)

SCALE_SERVICE_COMMAND=aws application-autoscaling register-scalable-target --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --min-capacity $1 --max-capacity $2 --resource-id service/shared-services-cluster/$3

scale-up-service:
ifndef SERVICE_NAME
	$(error SERVICE_NAME is not set)
endif
	$(call SCALE_SERVICE_COMMAND,1,2,$(SERVICE_NAME))

scale-down-service:
ifndef SERVICE_NAME
	$(error SERVICE_NAME is not set)
endif
	$(call SCALE_SERVICE_COMMAND,0,0,$(SERVICE_NAME))

ECS_SERVICES=terraform show -json | jq '.. | select(.name == "ecs-service")? | .values.id' -r | sort

scale-down-environment:
ifndef ENVIRONMENT_NAME
	$(error ENVIRONMENT_NAME is not set)
endif
	aws application-autoscaling describe-scalable-targets --service-namespace ecs --output text --query "ScalableTargets[?contains(to_string(ResourceId),'-$(ENVIRONMENT_NAME)-')].[ResourceId]" | xargs -tn 1 aws application-autoscaling register-scalable-target --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --min-capacity 0 --max-capacity 0 --resource-id

scale-up-environment:
ifndef ENVIRONMENT_NAME
	$(error ENVIRONMENT_NAME is not set)
endif
	aws application-autoscaling describe-scalable-targets --service-namespace ecs --output text --query "ScalableTargets[?contains(to_string(ResourceId),'-$(ENVIRONMENT_NAME)-')].[ResourceId]" | xargs -tn 1 aws application-autoscaling register-scalable-target --service-namespace ecs --scalable-dimension ecs:service:DesiredCount --min-capacity 1 --max-capacity 2 --resource-id

shut-off-all:
	$(ECS_SERVICES) | xargs -n 1 aws ecs update-service --desired-count 0 --cluster shared-services-cluster --output table --query "service.{Desired: desiredCount, Running: runningCount, Pending: pendingCount}" --service

shut-off-service:
ifndef SERVICE_NAME
	$(error SERVICE_NAME is not set)
endif
	aws ecs update-service --desired-count 0 --cluster shared-services-cluster --output table --query "service.{Desired: desiredCount, Running: runningCount, Pending: pendingCount}" --service $(SERVICE_NAME)

wait-services-stable:
	$(ECS_SERVICES_CLI) | xargs -n 10 aws ecs wait services-stable --cluster shared-services-cluster --output table --services

scale-targets:
	$(SCALE_TARGETS)

capacity-scaling:
	awsinfo appautoscaling targets ecs -- $(CURRENT_WORKSPACE)

capacity-services:
	$(ECS_SERVICES_CLI) | xargs -n 10 aws ecs describe-services --cluster shared-services-cluster --output table --query "services[].{\"1.Name\":serviceName,Desired: desiredCount, Running: runningCount, Pending: pendingCount}" --services

CURRENT_TAG = $$(docker inspect --format='{{index .Id}}' $1 | sed 's/sha256://')-$$(date -u +"%Y-%m-%dT%H-%M-%S")

ECR_DOMAIN = $(shell aws sts get-caller-identity --query Account --output text).dkr.ecr.$(shell aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]').amazonaws.com

ecr-login:
	aws ecr get-login-password | docker login --username AWS --password-stdin $(ECR_DOMAIN)

run-crawlers:
	terraform show -json | jq '.. | select(.type == "aws_glue_crawler")? | .values.id' -r | sort | xargs -tn 1 aws glue start-crawler --name
	awsinfo logs -s now glue crawler
