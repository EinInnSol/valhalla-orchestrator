#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - Deployment Verification Script
#
# This script verifies that your deployment is working correctly
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        🔍 VALHALLA DEPLOYMENT VERIFICATION              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    print_error "No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_status "Checking deployment for project: $PROJECT_ID"
echo ""

# Check if service exists
print_status "Checking Cloud Run service..."
REGION=${1:-us-central1}
SERVICE_NAME="valhalla-ai-hub"

SERVICE_EXISTS=$(gcloud run services list --region=$REGION --project=$PROJECT_ID --filter="metadata.name:$SERVICE_NAME" --format="value(metadata.name)" 2>/dev/null || echo "")

if [ -z "$SERVICE_EXISTS" ]; then
    print_error "Service '$SERVICE_NAME' not found in region $REGION"
    echo ""
    echo "Available services:"
    gcloud run services list --project=$PROJECT_ID
    echo ""
    print_warning "Run ./deploy-gcp.sh to deploy"
    exit 1
fi

print_success "Service found: $SERVICE_NAME"

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)")
print_success "Service URL: $SERVICE_URL"

# Check service status
print_status "Checking service health..."

# Test HTTP connectivity
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    print_success "Service is responding (HTTP $HTTP_CODE)"
else
    print_error "Service returned HTTP $HTTP_CODE"
    print_warning "This might be normal for Streamlit. Check manually: $SERVICE_URL"
fi

# Check Firestore
print_status "Checking Firestore..."
FIRESTORE_STATUS=$(gcloud firestore databases list --project=$PROJECT_ID 2>/dev/null | grep -c "(default)" || echo "0")

if [ "$FIRESTORE_STATUS" = "1" ]; then
    print_success "Firestore database found"
else
    print_error "Firestore not initialized"
fi

# Check required APIs
print_status "Checking enabled APIs..."

REQUIRED_APIS=(
    "run.googleapis.com"
    "firestore.googleapis.com"
    "aiplatform.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    ENABLED=$(gcloud services list --project=$PROJECT_ID --filter="name:$api" --format="value(name)" 2>/dev/null || echo "")
    if [ -n "$ENABLED" ]; then
        print_success "$api enabled"
    else
        print_error "$api NOT enabled"
    fi
done

# Check service account
print_status "Checking service account..."
SA_EMAIL="valhalla-service-account@${PROJECT_ID}.iam.gserviceaccount.com"
SA_EXISTS=$(gcloud iam service-accounts list --project=$PROJECT_ID --filter="email:$SA_EMAIL" --format="value(email)" || echo "")

if [ -n "$SA_EXISTS" ]; then
    print_success "Service account exists: $SA_EMAIL"
else
    print_warning "Service account not found: $SA_EMAIL"
fi

# Get recent logs
print_status "Fetching recent logs..."
echo ""

gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=10 --project=$PROJECT_ID 2>/dev/null || print_warning "Could not fetch logs"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Verification Summary${NC}"
echo ""
echo "  Service: $SERVICE_NAME"
echo "  URL: $SERVICE_URL"
echo "  Region: $REGION"
echo "  Project: $PROJECT_ID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Open the service URL in your browser"
echo "2. Test the chat functionality"
echo "3. Verify Vertex AI Claude is responding"
echo ""
echo -e "${YELLOW}Troubleshooting Commands:${NC}"
echo ""
echo "  View live logs:"
echo "  gcloud run services logs tail $SERVICE_NAME --region=$REGION"
echo ""
echo "  Describe service:"
echo "  gcloud run services describe $SERVICE_NAME --region=$REGION"
echo ""
echo "  Test Vertex AI:"
echo "  ./diagnose.sh"
echo ""
