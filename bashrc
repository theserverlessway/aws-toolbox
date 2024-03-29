eval "$(register-python-argcomplete formica)"

alias f="formica"

alias fnew="f new -c stack.config.yaml"
alias fchange="f change -c stack.config.yaml"
alias fdeploy="f deploy -c stack.config.yaml"
alias fdiff="f diff -c stack.config.yaml"
alias fremove="f remove -c stack.config.yaml"
alias fcancel="f cancel -c stack.config.yaml"

alias awsprofiles="cat ~/.aws/config | grep '\[profile'"
alias aws-unset="unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID AWS_DEFAULT_REGION AWS_PROFILE"

alias tp="terraform plan"
alias ta="terraform apply"
alias ti="terraform-init"
alias twl="terraform workspace list"
alias tws="terraform workspace select"
alias terraform-addresses="terraform show -json | jq -r '.values[].resources[].address' | sort"
alias tad="terraform-addresses"
alias tformat="terraform fmt -recursive ./"

alias a='awsinfo'
alias am="awsinfo me"
alias tar="\$(awsinfo assume role -r TerraformApplyRole --profile uits-pipeline) && terraform apply"
alias tpr="\$(awsinfo assume role -r TerraformApplyRole --profile uits-pipeline) && terraform plan"
alias amr="\$(awsinfo assume role -r TerraformApplyRole --profile uits-pipeline) && aws sts get-caller-identity"

function with-apply-role(){
  $(awsinfo assume role -r TerraformApplyRole --profile uits-pipeline)
  $@
}

function terraform-plan-summary {
  (with-apply-role __terraform-plan-summary)
}

function __terraform-plan-summary {
	terraform workspace list | sed 's/*\|default//g' | xargs -I {} -n 1 bash -c 'echo Planning for Workspace {} && terraform workspace select -no-color {} && terraform plan -no-color ' | tee all-workspaces-plan-output.txt | grep "Planning for Workspace\|No changes\|Plan:.*add.*change.*destroy"
}

function cloudtrail {
  awsinfo logs  -f "$1" -s -${2:-8}hours -wG CloudTrail | tail -n +2 | jq --slurp
}

function show_make_targets {
    if [ -f "Makefile" ]
    then
      has_include=$(cat Makefile | grep "^\s*include")
      if [ -z "$has_include"  ]
      then
          cat Makefile | grep -o "^[a-zA-Z0-9_\-]*:" | tr -d ":" | grep -v Makefile | sort
      else
          make -nqpRr Makefile | grep -o "^[a-zA-Z0-9_\-]*:" | tr -d ":" | grep -v Makefile | sort
      fi
    fi
}

complete -W '$(show_make_targets)' make

function terraform-init {
  AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  terraform init \
    -backend-config="bucket=terraform-state-$AWS_REGION-$ACCOUNT_ID" \
    -backend-config="key=terraform" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=terraform-lock-$AWS_REGION-$ACCOUNT_ID" \
    --reconfigure -upgrade
}

function terraform-upgrade {
  terraform init -upgrade
  terraform providers lock \
    -platform=darwin_amd64 \
    -platform=linux_amd64 \
    -platform=linux_arm
}

alias m="show_make_targets"

complete -C /usr/bin/terraform terraform

alias tf="terraform"

alias awsinfo="/awsinfo/scripts/awsinfo.bash"

source ~/.awsinfo_completion
complete -F _awsinfo_complete a

complete -C '/usr/local/bin/aws_completer' aws

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1='\[\e[0;32m\]\w \[\e[0;32m\]→\[\e[39m\] '

# GIT_PROMPT_ONLY_IN_REPO=1
# GIT_PROMPT_THEME="Single_line_Solarized"
# GIT_PROMPT_SHOW_UPSTREAM=1
# source /bash-git-prompt/gitprompt.sh

alias terraform-locks="aws dynamodb list-tables --output text --query \"TableNames[?contains(@,'terraform-lock')]\" | xargs aws dynamodb scan --query \"Items[?!contains(LockID.S,'md5')].LockID.S\" --output table --table-name"

function terraform-remove-lock {
  DYNAMO_TABLE=$(aws dynamodb list-tables --output text --query "TableNames[?contains(@,'terraform-lock')]")
  aws dynamodb delete-item --table-name $DYNAMO_TABLE --key "{\"LockID\":{\"S\": \"$1\"}}"
}

source /usr/share/bash-completion/completions/git

alias aws-unset-token='unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID'
__git_complete g __git_main


function __aws-profiles-list {
  cat ~/.aws/config ~/.aws/credentials | grep "^\[.*\]" | sed -E 's/(\[profile |\[)(.*)\]/\2/g' | sort | uniq
}

function aws-profiles-switch {
  export AWS_PROFILE=$1
}

alias apl='aws-profiles-list'
alias aps='aws-profiles-switch'

complete -W '$(__aws-profiles-list)' aws-profiles-switch
complete -W '$(__aws-profiles-list)' aps

function __aws-regions-list {
  echo eu-north-1	ap-south-1	eu-west-3	eu-west-2	eu-west-1	ap-northeast-3	ap-northeast-2	ap-northeast-1	sa-east-1	ca-central-1	ap-southeast-1	ap-southeast-2	eu-central-1	us-east-1	us-east-2	us-west-1	us-west-2
}

function aws-regions-switch {
  export AWS_DEFAULT_REGION=$1 AWS_REGION=$1
}

alias arl='__aws-regions-list'
alias ars='aws-regions-switch'

complete -W '$(__aws-regions-list)' aws-regions-switch
complete -W '$(__aws-regions-list)' ars

function aws-ecr-login {
  AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ECR_DOMAIN=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
  echo $ECR_DOMAIN
  aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_DOMAIN
}

export AWS_PAGER=""

alias aws-ecs-tasks='awsinfo ecs tasks && awsinfo ecs tasks -s'
alias aws-ecs-tasks-watch="watch -c \'awsinfo ecs tasks && awsinfo ecs tasks -s\'"

alias ecr-login=aws-ecr-login

# CURL

alias c='curl'
alias curl-headers='c --head -L -X GET'


alias watch='watch -c'

export PATH="/toolbox-scripts:$PATH"
