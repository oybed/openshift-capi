#!/bin/bash -x

aws iam set-security-token-service-preferences --global-endpoint-token-version v2Token

ROSA_CLUSTER_NAME="${1:-rosa-hcp}"
AWS_REGION="${2:-us-east-1}"
AZ_NAME="${AWS_REGION}a"

VPC_ID_VALUE=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text`
aws ec2 create-tags --resources $VPC_ID_VALUE --tags Key=Name,Value=$ROSA_CLUSTER_NAME
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID_VALUE --enable-dns-hostnames

PUBLIC_SUBNET_ID=`aws ec2 create-subnet --vpc-id $VPC_ID_VALUE --cidr-block 10.0.1.0/24 --availability-zone $AZ_NAME --query Subnet.SubnetId --output text`
aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=Name,Value=$ROSA_CLUSTER_NAME-public

PRIVATE_SUBNET_ID=`aws ec2 create-subnet --vpc-id $VPC_ID_VALUE --cidr-block 10.0.0.0/24 --availability-zone $AZ_NAME --query Subnet.SubnetId --output text`
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID --tags Key=Name,Value=$ROSA_CLUSTER_NAME-private

IG_ID_VALUE=`aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text`
aws ec2 attach-internet-gateway --vpc-id $VPC_ID_VALUE --internet-gateway-id $IG_ID_VALUE
aws ec2 create-tags --resources $IG_ID_VALUE --tags Key=Name,Value=$ROSA_CLUSTER_NAME

PUBLIC_RT_ID=`aws ec2 create-route-table --vpc-id $VPC_ID_VALUE --query RouteTable.RouteTableId --output text`
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUBLIC_RT_ID
aws ec2 create-route --route-table-id $PUBLIC_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IG_ID_VALUE
aws ec2 create-tags --resources $PUBLIC_RT_ID --tags Key=Name,Value=$ROSA_CLUSTER_NAME

# aws ec2 describe-route-tables --route-table-id <PUBLIC_RT_ID>

EIP_ADDRESS=`aws ec2 allocate-address --domain vpc --query AllocationId --output text`
NAT_GATEWAY_ID=`aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID --allocation-id $EIP_ADDRESS --query NatGateway.NatGatewayId --output text`
aws ec2 create-tags --resources $EIP_ADDRESS --resources $NAT_GATEWAY_ID --tags Key=Name,Value=$ROSA_CLUSTER_NAME

PRIVATE_RT_ID=`aws ec2 create-route-table --vpc-id $VPC_ID_VALUE --query RouteTable.RouteTableId --output text`
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID --route-table-id $PRIVATE_RT_ID
aws ec2 create-route --route-table-id $PRIVATE_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GATEWAY_ID
aws ec2 create-tags --resources $PRIVATE_RT_ID $EIP_ADDRESS --tags Key=Name,Value=$ROSA_CLUSTER_NAME-private
