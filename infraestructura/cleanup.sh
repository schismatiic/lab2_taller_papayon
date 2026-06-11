## BORRAR TODO DESDE LA ULTIMA VEZ QUE SE EJECUTO deploy.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

SERVICE_ARNs=$(aws ecs list-services \
  --cluster "$CLUSTER" \
  --region "$AWS_REGION" \
  --query "serviceArns[]" \
  --output text)

for s in $SERVICE_ARNs; do
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$s" \
    --desired-count 0 \
    --region "$AWS_REGION" ||
    true

  aws ecs delete-service \
    --cluster "$CLUSTER" \
    --service "$s" \
    --force \
    --region "$AWS_REGION" ||
    true
done

## LISTENER

## ALB

aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN" \
  --region "$AWS_REGION" || true

## TG

aws elbv2 delete-target-group \
  --target-group-arn "$TG_ARN" \
  --region "$AWS_REGION" || true

## CLUSTER

aws ecs delete-cluster \
  --cluster "$CLUSTER" \
  --region "$AWS_REGION" || true

## SG

aws ec2 delete-security-group \
  --group-id "$SG_ID" \
  --region "$AWS_REGION" || true

## RouteTables

ASSOC_IDS=$(aws ec2 describe-route-tables \
  --route-table-id "$PUBLIC_RT_ID" \
  --region us-east-1 \
  --query "RouteTables[0].Associations[?Main!=\`true\`].RouteTableAssociationId" \
  --output text)

for a in $ASSOC_IDS; do
  aws ec2 disassociate-route-table \
    --association-id "$a" \
    --region us-east-1 ||
    true
done

aws ec2 delete-route-table \
  --route-table-id "$PUBLIC_RT_ID" \
  --region us-east-1 ||
  true

## IGW

aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region us-east-1 || true

aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --region us-east-1 || true

## SUBNETS

aws ec2 delete-subnet \
  --subnet-id "$SUBNET_A_ID" \
  --region us-east-1 ||
  true

aws ec2 delete-subnet \
  --subnet-id "$SUBNET_B_ID" \
  --region us-east-1 ||
  true

## VPC

aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region us-east-1 ||
  true
