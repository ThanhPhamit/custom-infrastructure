#!/bin/bash

DEPLOYMENT_ID=$(aws deploy create-deployment \
--application-name ${application_name} \
--deployment-group-name ${deployment_group_name} \
--s3-location bucket=${s3_bucket},key=${key},bundleType=${bundle_type} \
--deployment-config-name ${deployment_config_name} \
--query "deploymentId" --output text)

echo "Deployment ID: $DEPLOYMENT_ID"