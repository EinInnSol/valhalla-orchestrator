#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - Cost Checker
#
# Quick script to check current GCP spending
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
║        💰 CURRENT COST CHECK                            ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Get project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    print_error "No project set"
    exit 1
fi

print_status "Checking costs for: $PROJECT_ID"
echo ""

# Get billing account
BILLING_ACCOUNT=$(gcloud billing projects describe $PROJECT_ID --format="value(billingAccountName)" 2>/dev/null | sed 's|billingAccounts/||' || echo "")

if [ -z "$BILLING_ACCOUNT" ]; then
    print_error "No billing account linked"
    exit 1
fi

# Current month dates
CURRENT_MONTH=$(date +%Y-%m-01)
NEXT_MONTH=$(date -d "$CURRENT_MONTH +1 month" +%Y-%m-01 2>/dev/null || date -v+1m -j -f %Y-%m-%d $CURRENT_MONTH +%Y-%m-%d)

print_status "Fetching billing data..."
echo "  Period: $CURRENT_MONTH to $NEXT_MONTH"
echo "  Billing Account: $BILLING_ACCOUNT"
echo ""

# Note: Detailed cost queries require proper permissions
# We'll show what commands to use

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}OPTION 1: View in GCP Console (Most Detailed)${NC}"
echo ""
echo "Monthly costs:"
echo "  https://console.cloud.google.com/billing/reports?project=$PROJECT_ID"
echo ""
echo "Current month breakdown:"
echo "  https://console.cloud.google.com/billing/$BILLING_ACCOUNT/reports"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}OPTION 2: Query via gcloud${NC}"
echo ""
echo "# List all billing accounts"
echo "gcloud billing accounts list"
echo ""
echo "# Get project billing info"
echo "gcloud billing projects describe $PROJECT_ID"
echo ""

# Try to get service usage
print_status "Service Usage (Current Month):"
echo ""

# Cloud Run
print_status "Cloud Run:"
CLOUD_RUN_SERVICES=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l || echo "0")
echo "  Active services: $CLOUD_RUN_SERVICES"

if [ "$CLOUD_RUN_SERVICES" -gt "0" ]; then
    echo "  Services:"
    gcloud run services list --format="table(metadata.name,status.url,status.conditions[0].status)" 2>/dev/null || echo "  Unable to fetch details"
fi
echo ""

# Firestore
print_status "Firestore:"
FIRESTORE_DBS=$(gcloud firestore databases list --format="value(name)" 2>/dev/null | wc -l || echo "0")
echo "  Databases: $FIRESTORE_DBS"
echo ""

# Cloud Build
print_status "Cloud Build:"
echo "  Recent builds:"
gcloud builds list --limit=5 --format="table(id,status,createTime,duration)" 2>/dev/null || echo "  No recent builds"
echo ""

# Container Registry
print_status "Container Registry:"
echo "  Images stored:"
gcloud container images list --format="value(name)" 2>/dev/null | wc -l || echo "  0"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Estimated Monthly Costs (Based on Usage)${NC}"
echo ""

# Rough estimates based on service usage
echo "Cloud Run:"
echo "  • Minimal usage (within free tier): ~\$0-5/month"
echo ""
echo "Vertex AI Claude:"
echo "  • Check recent requests in app sidebar"
echo "  • Estimate: \$0.003 per 1K input + \$0.015 per 1K output"
echo ""
echo "Firestore:"
echo "  • Likely within free tier: \$0-2/month"
echo ""
echo "Total Estimated: \$0-30/month for light-moderate use"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Cost Monitoring Tips:${NC}"
echo ""
echo "1. Check GCP Console daily:"
echo "   https://console.cloud.google.com/billing/reports"
echo ""
echo "2. Set up budget alerts:"
echo "   ./setup-budget-alerts.sh"
echo ""
echo "3. Monitor Vertex AI usage in app sidebar"
echo ""
echo "4. Enable billing export to BigQuery for detailed analysis:"
echo "   https://console.cloud.google.com/billing/$BILLING_ACCOUNT/export"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_success "Cost check complete!"
echo ""
print_warning "For exact costs, check GCP Console Billing Reports"
echo ""
