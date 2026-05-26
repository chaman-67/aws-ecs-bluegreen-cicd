#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Blue/Green deploy to AWS ECS via CodeDeploy
#   Usage: ./deploy.sh <full-ecr-image-uri>
#   Reads cluster/service/task-family from env or defaults below
# ─────────────────────────────────────────────────────────────
set -euo pipefail

IMAGE="${1:-}"
[[ -z "$IMAGE" ]] && { echo "ERROR: image URI required"; echo "Usage: $0 <image-uri>"; exit 1; }

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECS_CLUSTER="${ECS_CLUSTER:-production}"
ECS_SERVICE="${ECS_SERVICE:-sample-api}"
TASK_FAMILY="${TASK_FAMILY:-sample-api}"
CODEDEPLOY_APP="${CODEDEPLOY_APP:-AppECS-${ECS_CLUSTER}-${ECS_SERVICE}}"
CODEDEPLOY_GROUP="${CODEDEPLOY_GROUP:-DgpECS-${ECS_CLUSTER}-${ECS_SERVICE}}"

log()  { printf "\033[1;36m[deploy]\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m[fail]\033[0m   %s\n" "$*" >&2; exit 1; }

log "image:    $IMAGE"
log "cluster:  $ECS_CLUSTER"
log "service:  $ECS_SERVICE"

# 1. Fetch current task definition
log "fetching current task definition…"
CURRENT_TD=$(aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --region "$AWS_REGION" \
  --query 'taskDefinition' --output json)

# 2. Update image in container definition
log "rendering new task definition with updated image…"
NEW_TD=$(echo "$CURRENT_TD" | jq --arg IMAGE "$IMAGE" '
  .containerDefinitions[0].image = $IMAGE
  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
        .compatibilities, .registeredAt, .registeredBy)
')

# 3. Register new task definition revision
log "registering new revision…"
NEW_TD_ARN=$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json "$NEW_TD" \
  --query 'taskDefinition.taskDefinitionArn' --output text)
log "registered: $NEW_TD_ARN"

# 4. Build CodeDeploy appspec
APPSPEC=$(cat <<EOF
{
  "version": 1,
  "Resources": [{
    "TargetService": {
      "Type": "AWS::ECS::Service",
      "Properties": {
        "TaskDefinition": "${NEW_TD_ARN}",
        "LoadBalancerInfo": {
          "ContainerName": "${ECS_SERVICE}",
          "ContainerPort": 3000
        }
      }
    }
  }]
}
EOF
)

# 5. Trigger CodeDeploy blue/green deployment
log "triggering CodeDeploy blue/green deployment…"
DEPLOY_ID=$(aws deploy create-deployment \
  --region "$AWS_REGION" \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --revision "{\"revisionType\":\"AppSpecContent\",\"appSpecContent\":{\"content\":$(echo "$APPSPEC" | jq -Rs .)}}" \
  --query 'deploymentId' --output text)

log "deployment id: $DEPLOY_ID"

# 6. Wait for completion
log "waiting for deployment to complete…"
aws deploy wait deployment-successful \
  --region "$AWS_REGION" \
  --deployment-id "$DEPLOY_ID" \
  || fail "deployment $DEPLOY_ID did not succeed"

# Save for rollback
echo "$NEW_TD_ARN" > .last-deployed-td.txt
echo "$DEPLOY_ID"   > .last-deployment-id.txt

log "✓ deployment $DEPLOY_ID succeeded"
