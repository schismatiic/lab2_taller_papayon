## BORRAR TODO DESDE LA ULTIMA VEZ QUE SE EJECUTO deploy.sh
## Perdon profe por los sleep pero es la forma mas facil de deshacerse de las dependencias

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../vars.sh"

aws ecs update-service --cluster $CLUSTER --service "${APP}-svc" --desired-count 0
aws ecs delete-service --cluster $CLUSTER --service "${APP}-svc" --force

sleep 40

aws ecs delete-cluster --cluster $CLUSTER

sleep 40
## ALB

aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN" \
  --region "$AWS_REGION"

aws elbv2 wait load-balancers-deleted \
  --load-balancer-arns "$ALB_ARN" \
  --region "$AWS_REGION" || true

sleep 40
## TG

aws elbv2 delete-target-group \
  --target-group-arn "$TG_ARN" \
  --region "$AWS_REGION" || true

## SG

sleep 30

aws ec2 delete-security-group \
  --group-id "$SG_ID" \
  --region "$AWS_REGION" || true

sleep 20

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

sleep 20

## IGW

aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region us-east-1 || true

aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --region us-east-1 || true

sleep 20

## SUBNETS

aws ec2 delete-subnet \
  --subnet-id "$SUBNET_A_ID" \
  --region us-east-1 ||
  true

sleep 20

aws ec2 delete-subnet \
  --subnet-id "$SUBNET_B_ID" \
  --region us-east-1 ||
  true

sleep 20

## VPC

aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region us-east-1 ||
  true

echo "Done"
