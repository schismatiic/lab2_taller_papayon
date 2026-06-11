#!/bin/bash

## La primera parte la copiamos y pegamos del lab anterior
clear
echo "Deploying paparuta."

## checkeamos que aws-cli este instalado

if
  command -v aws >/dev/null 2>&1
then
  echo "aws-cli instalado"
else
  ## salimos del script con un error
  echo "aws-cli no esta instalado"
  exit 1
fi

## Vamos a asumir que aws configure ya fue ejecutado
## Si no esta en json no funcionara

## construimos la version 1.0 del negocio
docker build -t paparuta:1.1 .
#docker run --rm -p 8080:80 paparuta:1.0 &
export TIMESTAMP=$(date +%Y%m%d-%H%M%S)
export APP=paparuta
## Pusheamos la version 1.0
export AWS_REGION=us-east-1
epoxrt ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REPO=paparuta
aws ecr create-repository --repository-name $REPO --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION |
  docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
export IMG=$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:1.0
docker tag paparuta:1.0 $IMG && docker push $IMG

## El comando retornara un json asi que lo usaremos de variable
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region us-east-1 \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC id: $VPC_ID"

## Subnets

## Subnets publicas en dos zonas distintas us-east-1a/b
export SUBNET_A_ID=$(
  aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-east-1a \
    --region us-east-1 \
    --query 'Subnet.SubnetId' \
    --output text
)

export SUBNET_B_ID=$(
  aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone us-east-1b \
    --region us-east-1 \
    --query 'Subnet.SubnetId' \
    --output text
)

echo "Subnet Ids"
echo "Public: $SUBNET_A_ID on us-east-1a and $SUBNET_B_ID on us-east-1b"

## Gateways

export IGW_ID=$(
  aws ec2 create-internet-gateway \
    --region us-east-1 \
    --query 'InternetGateway.InternetGatewayId' \
    --output text
)

echo "IGW id: $IGW_ID"

## asociamos el gateway a la vpc dandole acceso a internet
## no hace falta guardarlo en una variable

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region us-east-1

## Route tables

export PUBLIC_RT_ID=$(
  aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --region us-east-1 \
    --query 'RouteTable.RouteTableId' \
    --output text
)

aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region us-east-1

aws ec2 associate-route-table \
  --subnet-id $SUBNET_A_ID \
  --route-table-id $PUBLIC_RT_ID \
  --region us-east-1

aws ec2 associate-route-table \
  --subnet-id $SUBNET_B_ID \
  --route-table-id $PUBLIC_RT_ID \
  --region us-east-1

## Security Groups

export SG_ID=$(
  aws ec2 create-security-group \
    --group-name Paparuta-SG \
    --description "Security group para papruta" \
    --vpc-id $VPC_ID \
    --region us-east-1 \
    --query "GroupId" \
    --output text
)
echo "Security group ID: $SG_ID"

export MY_IP=$(curl -s ifconfig.me)

## ssh desde la ip publica del computador que corre el script

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_IP}/32 \
  --region us-east-1

## HTTP desde cualquier ip

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region us-east-1

## CLUSTER

export CLUSTER=papa-cluster-$TIMESTAMP

aws ecs create-cluster \
  --cluster-name $CLUSTER \
  --capacity-providers FARGATE \
  --region $AWS_REGION

## TARGET GROUP

export TG_ARN=$(aws elbv2 create-target-group \
  --name papa-tg-$TIMESTAMP \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path / \
  --region $AWS_REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

## ALB

export ALB_ARN=$(aws elbv2 create-load-balancer \
  --name papa-alb-$TIMESTAMP \
  --subnets $SUBNET_A_ID $SUBNET_B_ID \
  --security-groups $SG_ID \
  --scheme internet-facing \
  --type application \
  --region $AWS_REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

## LISTENER

export LISTENER_ARN $(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $AWS_REGION)

## TASKDEF

##
cat >taskdef.json <<JSON
{ "family": "$APP", "networkMode": "awsvpc",
"requiresCompatibilities": ["FARGATE"],
"cpu": "256", "memory": "512",
"executionRoleArn": "arn:aws:iam::$ACCOUNT:role/ecsTaskExecutionRole",
"containerDefinitions": [{ "name": "web",
"image": "$IMG",
"portMappings": [{ "containerPort": 80 }] }] }
JSON
aws ecs register-task-definition --cli-input-json file://taskdef.json

aws ecs create-service --cluster $CLUSTER --service-name $APP-svc \
  --task-definition $APP --desired-count 2 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A_ID,$SUBNET_B_ID],\
securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=web,containerPort=80"

### EC2
### Si ya tienes la key va a tirar un error pero funcionara
#
### ponemos el date a la key para eliminar error del laboratorio pasado con claves repetidas
###
#KEYNAME="papakey-$(date +%Y%m%d-%H%M%S)"
#KEYPATH="$HOME/.ssh/$KEYNAME.pem"
#
#aws ec2 create-key-pair \
#  --key-name $KEYNAME \
#  --query 'KeyMaterial' \
#  --output text \
#  --region us-east-1 >"$KEYPATH"
#
### permisos del .pem
### necesitamos sudo porque no me dio permisos
#
#sudo chmod 400 "$KEYPATH"
#
### Desplegar el EC2
#
#echo "Desplegando EC2..."
#
#EC2_ID=$(aws ec2 run-instances \
#  --image-id ami-0fc5d935ebf8bc3bc \
#  --count 1 \
#  --instance-type t3.micro \
#  --key-name "$KEYNAME" \
#  --security-group-ids $SG_ID \
#  --subnet-id $PUBLIC_SUBNET_ID \
#  --associate-public-ip-address \
#  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=paprutaServer}]' \
#  --region us-east-1 \
#  --query "Instances[0].InstanceId" \
#  --output text)
#
### Esperamos a que la EC2 este lista
#aws ec2 wait instance-running --instance-ids $EC2_ID
#
#PUBLIC_IP=$(
#  aws ec2 describe-instances \
#    --instance-ids $EC2_ID \
#    --query "Reservations[*].Instances[*].PublicIpAddress" \
#    --output text \
#    --region us-east-1
#)

# exportamos todas las variables para luego reutilizarlas en la limpieza
export -p >vars.sh
