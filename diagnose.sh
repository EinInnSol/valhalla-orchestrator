#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - Diagnostic Script
#
# Comprehensive diagnostics for troubleshooting deployment issues
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
║           🔧 VALHALLA DIAGNOSTIC TOOL                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Get configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
REGION=${1:-us-central1}

echo ""
print_status "Running comprehensive diagnostics..."
echo ""

# Test 1: GCloud CLI
print_status "Test 1: GCloud CLI Installation"
if command -v gcloud >/dev/null 2>&1; then
    GCLOUD_VERSION=$(gcloud version --format="value(core)" 2>/dev/null)
    print_success "gcloud CLI installed: $GCLOUD_VERSION"
else
    print_error "gcloud CLI not found"
    exit 1
fi

# Test 2: Authentication
print_status "Test 2: GCP Authentication"
AUTH_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || echo "")
if [ -n "$AUTH_ACCOUNT" ]; then
    print_success "Authenticated as: $AUTH_ACCOUNT"
else
    print_error "Not authenticated. Run: gcloud auth login"
    exit 1
fi

# Test 3: Project Configuration
print_status "Test 3: Project Configuration"
if [ -n "$PROJECT_ID" ]; then
    print_success "Project set: $PROJECT_ID"
else
    print_error "No project set. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# Test 4: Required APIs
print_status "Test 4: Required APIs"

APIS=(
    "run.googleapis.com:Cloud Run"
    "firestore.googleapis.com:Firestore"
    "aiplatform.googleapis.com:Vertex AI"
    "cloudbuild.googleapis.com:Cloud Build"
    "logging.googleapis.com:Cloud Logging"
)

API_ISSUES=0
for api_info in "${APIS[@]}"; do
    IFS=':' read -r api name <<< "$api_info"
    ENABLED=$(gcloud services list --project=$PROJECT_ID --filter="name:$api" --format="value(name)" 2>/dev/null || echo "")
    if [ -n "$ENABLED" ]; then
        print_success "$name enabled"
    else
        print_error "$name NOT enabled"
        API_ISSUES=$((API_ISSUES + 1))
    fi
done

if [ $API_ISSUES -gt 0 ]; then
    echo ""
    print_warning "Enable missing APIs with:"
    echo "  gcloud services enable run.googleapis.com firestore.googleapis.com aiplatform.googleapis.com --project=$PROJECT_ID"
    echo ""
fi

# Test 5: Vertex AI Model Access
print_status "Test 5: Vertex AI Model Garden"
echo ""
print_warning "Checking Vertex AI model access requires manual verification"
echo ""
echo "  1. Visit: https://console.cloud.google.com/vertex-ai/model-garden?project=$PROJECT_ID"
echo "  2. Search for 'Claude'"
echo "  3. Verify 'Claude 3.5 Sonnet' is enabled"
echo ""
read -p "  Is Claude 3.5 Sonnet enabled? (y/n): " CLAUDE_ENABLED

if [ "$CLAUDE_ENABLED" = "y" ] || [ "$CLAUDE_ENABLED" = "Y" ]; then
    print_success "Claude confirmed enabled"
else
    print_error "Claude not enabled - this will cause chat failures"
fi

# Test 6: Firestore
print_status "Test 6: Firestore Database"
FIRESTORE_EXISTS=$(gcloud firestore databases list --project=$PROJECT_ID 2>/dev/null | grep -c "(default)" || echo "0")

if [ "$FIRESTORE_EXISTS" = "1" ]; then
    print_success "Firestore database exists"

    # Check if we can access it
    print_status "Testing Firestore access..."

    # Try to list collections (requires authentication)
    python3 << 'PYTHON_TEST'
try:
    from google.cloud import firestore
    import os
    os.environ['GCP_PROJECT_ID'] = '$PROJECT_ID'
    db = firestore.Client()
    collections = list(db.collections(max_results=1))
    print("✓ Firestore accessible")
except Exception as e:
    print(f"✗ Firestore access error: {e}")
PYTHON_TEST

else
    print_error "Firestore not initialized"
    echo ""
    print_warning "Initialize Firestore with:"
    echo "  gcloud firestore databases create --location=$REGION --project=$PROJECT_ID"
    echo ""
fi

# Test 7: Cloud Run Service
print_status "Test 7: Cloud Run Deployment"
SERVICE_NAME="valhalla-ai-hub"
SERVICE_EXISTS=$(gcloud run services list --region=$REGION --project=$PROJECT_ID --filter="metadata.name:$SERVICE_NAME" --format="value(metadata.name)" 2>/dev/null || echo "")

if [ -n "$SERVICE_EXISTS" ]; then
    print_success "Service deployed: $SERVICE_NAME"

    # Get service details
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>/dev/null)
    SERVICE_STATUS=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.conditions[0].status)" 2>/dev/null)

    echo "    URL: $SERVICE_URL"
    echo "    Status: $SERVICE_STATUS"

    # Test HTTP connectivity
    print_status "Testing HTTP connectivity..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$SERVICE_URL" || echo "000")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        print_success "Service responding (HTTP $HTTP_CODE)"
    else
        print_warning "Service returned HTTP $HTTP_CODE (may be normal for Streamlit)"
    fi
else
    print_error "Service not deployed"
    echo ""
    print_warning "Deploy the service with:"
    echo "  ./deploy-gcp.sh"
    echo ""
fi

# Test 8: IAM Permissions
print_status "Test 8: Service Account & IAM"
SA_EMAIL="valhalla-service-account@${PROJECT_ID}.iam.gserviceaccount.com"
SA_EXISTS=$(gcloud iam service-accounts list --project=$PROJECT_ID --filter="email:$SA_EMAIL" --format="value(email)" 2>/dev/null || echo "")

if [ -n "$SA_EXISTS" ]; then
    print_success "Service account exists"

    # Check roles
    print_status "Checking IAM roles..."
    ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:serviceAccount:$SA_EMAIL" --format="value(bindings.role)" 2>/dev/null || echo "")

    if echo "$ROLES" | grep -q "aiplatform.user"; then
        print_success "Vertex AI User role assigned"
    else
        print_error "Missing Vertex AI User role"
    fi

    if echo "$ROLES" | grep -q "datastore.user"; then
        print_success "Datastore User role assigned"
    else
        print_error "Missing Datastore User role"
    fi
else
    print_error "Service account not found"
fi

# Test 9: Python Dependencies
print_status "Test 9: Python Environment"
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_success "Python installed: $PYTHON_VERSION"

    # Check if required packages are available
    python3 << 'PYTHON_CHECK'
packages = ['streamlit', 'google.cloud.aiplatform', 'google.cloud.firestore']
for pkg in packages:
    try:
        __import__(pkg)
        print(f"  ✓ {pkg}")
    except ImportError:
        print(f"  ✗ {pkg} not installed")
PYTHON_CHECK
else
    print_warning "Python 3 not found (not required for Cloud Run)"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Diagnostic Summary${NC}"
echo ""
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Account: $AUTH_ACCOUNT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $API_ISSUES -eq 0 ] && [ -n "$SERVICE_EXISTS" ] && [ "$FIRESTORE_EXISTS" = "1" ]; then
    echo -e "${GREEN}✓ All critical systems operational${NC}"
    echo ""
    echo "  Your Valhalla Orchestrator appears to be working correctly!"
    echo ""
else
    echo -e "${YELLOW}⚠ Some issues detected${NC}"
    echo ""
    echo "  Please review the errors above and follow the suggested fixes."
    echo ""
fi

echo -e "${YELLOW}Need Help?${NC}"
echo ""
echo "  View logs: gcloud run services logs tail valhalla-ai-hub --region=$REGION"
echo "  Verify deployment: ./verify-deployment.sh"
echo "  Redeploy: ./deploy-gcp.sh"
echo ""
