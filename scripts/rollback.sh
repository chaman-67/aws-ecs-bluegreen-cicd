#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Rollback last deployment by re-deploying the previous revision
#   Usage: ./rollback.sh [revisions-back, default 1]
# ─────────────────────────────────────────────────────────────
set -euo pipefail

BACK="${1:-1}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
TASK_FAMILY="${TASK_FAMILY:-sample-api}"
ECS_CLUSTER="${ECS_CLUSTER:-production}"
ECS_SERVICE="${ECS_SERVICE:-sample-api}"
CODEDEPLOY_APP="${CODEDEPLOY_APP:-AppECS-${ECS_CLUSTER}-${ECS_SERVICE}}"
CODEDEPLOY_GROUP="${CODEDEPLOY_GROUP:-DgpECS-${ECS_CLUSTER}-${ECS_SERVICE}}"

log() { printf "\033[1;33m[rollback]\033[0m %s\n" "$*"; }

log "looking up previous task definition revision…"
LATEST_REV=$(aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.revision' --output text)

TARGET_REV=$((LATEST_REV - BACK))
[[ "$TARGET_REV" -lt 1 ]] && { echo "ERROR: nothing to roll back to"; exit 1; }

TARGET_ARN=$(aws ecs describe-task-definition \
  --task-definition "${TASK_FAMILY}:${TARGET_REV}" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

log "rolling back to: $TARGET_ARN"

APPSPEC=$(cat <<EOF
{
  "version": 1,
  "Resources": [{
    "TargetService": {
      "Type": "AWS::ECS::Service",
      "Properties": {
        "TaskDefinition": "${TARGET_ARN}",
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

DEPLOY_ID=$(aws deploy create-deployment \
  --region "$AWS_REGION" \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --description "Automated rollback of broken release" \
  --revision "{\"revisionType\":\"AppSpecContent\",\"appSpecContent\":{\"content\":$(echo "$APPSPEC" | jq -Rs .)}}" \
  --query 'deploymentId' --output text)

log "rollback deployment id: $DEPLOY_ID"
aws deploy wait deployment-successful \
  --region "$AWS_REGION" \
  --deployment-id "$DEPLOY_ID"

log "✓ rollback complete"
