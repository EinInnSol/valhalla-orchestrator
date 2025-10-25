#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - Budget Alert Setup
#
# This script sets up budget alerts to ensure you stay within $100/month
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
║        💰 BUDGET ALERT SETUP                            ║
║           Stay Within Your $100/month Limit              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    print_error "No GCP project set"
    echo "Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_status "Setting up budget alerts for project: $PROJECT_ID"
echo ""

# Get billing account
print_status "Finding billing account..."
BILLING_ACCOUNT=$(gcloud billing projects describe $PROJECT_ID --format="value(billingAccountName)" 2>/dev/null | sed 's|billingAccounts/||' || echo "")

if [ -z "$BILLING_ACCOUNT" ]; then
    print_error "No billing account found for this project"
    echo ""
    echo "Please enable billing for this project:"
    echo "https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    exit 1
fi

print_success "Billing account: $BILLING_ACCOUNT"
echo ""

# Budget settings
MONTHLY_BUDGET=${1:-100}  # Default $100/month
CURRENCY="USD"

print_status "Budget Configuration:"
echo "  Monthly Budget: \$${MONTHLY_BUDGET}"
echo "  Currency: ${CURRENCY}"
echo "  Alerts at: 25%, 50%, 75%, 95%"
echo ""

read -p "Is this correct? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo ""
    read -p "Enter your monthly budget in USD: " MONTHLY_BUDGET
fi

# Notification email
echo ""
print_status "Email notifications will be sent to budget alerts"
read -p "Enter your email for budget alerts: " ALERT_EMAIL

if [ -z "$ALERT_EMAIL" ]; then
    print_warning "No email provided - using console notifications only"
    ALERT_EMAIL=""
fi

# Create budget using gcloud
print_status "Creating budget with alerts..."

# Budget display name
BUDGET_NAME="valhalla-orchestrator-budget"
BUDGET_DISPLAY_NAME="Valhalla Orchestrator Monthly Budget"

# Create budget JSON configuration
cat > /tmp/budget-config.json <<EOF
{
  "displayName": "$BUDGET_DISPLAY_NAME",
  "budgetFilter": {
    "projects": ["projects/$PROJECT_ID"]
  },
  "amount": {
    "specifiedAmount": {
      "currencyCode": "$CURRENCY",
      "units": "$MONTHLY_BUDGET"
    }
  },
  "thresholdRules": [
    {
      "thresholdPercent": 0.25,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.50,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.75,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.95,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 1.0,
      "spendBasis": "CURRENT_SPEND"
    }
  ]
}
EOF

# Note: Budget creation via gcloud requires billing permissions
# We'll provide instructions instead
print_warning "Budget creation requires billing admin permissions"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}OPTION 1: Create Budget via GCP Console (Recommended)${NC}"
echo ""
echo "1. Go to: https://console.cloud.google.com/billing/$BILLING_ACCOUNT/budgets"
echo "2. Click 'CREATE BUDGET'"
echo "3. Enter these values:"
echo ""
echo "   Name: $BUDGET_DISPLAY_NAME"
echo "   Projects: $PROJECT_ID"
echo "   Budget Amount: \$${MONTHLY_BUDGET} per month"
echo ""
echo "4. Set threshold rules:"
echo "   - Alert at 25% (\$$(($MONTHLY_BUDGET / 4)))"
echo "   - Alert at 50% (\$$(($MONTHLY_BUDGET / 2)))"
echo "   - Alert at 75% (\$$(($MONTHLY_BUDGET * 3 / 4)))"
echo "   - Alert at 95% (\$$(($MONTHLY_BUDGET * 95 / 100)))"
echo "   - Alert at 100% (\$${MONTHLY_BUDGET})"
echo ""
echo "5. Add email recipients (optional): $ALERT_EMAIL"
echo "6. Click 'FINISH'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}OPTION 2: Create via gcloud (If you have billing admin role)${NC}"
echo ""
echo "gcloud billing budgets create \\"
echo "  --billing-account=$BILLING_ACCOUNT \\"
echo "  --display-name=\"$BUDGET_DISPLAY_NAME\" \\"
echo "  --budget-amount=${MONTHLY_BUDGET}USD \\"
echo "  --threshold-rule=percent=0.25 \\"
echo "  --threshold-rule=percent=0.50 \\"
echo "  --threshold-rule=percent=0.75 \\"
echo "  --threshold-rule=percent=0.95 \\"
echo "  --threshold-rule=percent=1.0"

if [ -n "$ALERT_EMAIL" ]; then
    echo "  --notifications-rule-pubsub-topic=projects/$PROJECT_ID/topics/budget-alerts \\"
    echo "  --notifications-rule-monitoring-notification-channels=$ALERT_EMAIL"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Additional monitoring setup
print_status "Setting up additional cost controls..."
echo ""

# Create Cloud Function for auto-shutdown (optional)
print_warning "OPTIONAL: Auto-Shutdown at 95% Budget"
echo ""
echo "You can create a Cloud Function that automatically scales down"
echo "Cloud Run when you hit 95% of budget."
echo ""
read -p "Would you like instructions for this? (y/n): " WANT_AUTOSHUTDOWN

if [ "$WANT_AUTOSHUTDOWN" = "y" ] || [ "$WANT_AUTOSHUTDOWN" = "Y" ]; then
    echo ""
    echo "Auto-shutdown setup:"
    echo ""
    echo "1. Create Pub/Sub topic for budget alerts:"
    echo "   gcloud pubsub topics create budget-alerts"
    echo ""
    echo "2. Link topic to budget (in console)"
    echo ""
    echo "3. Create Cloud Function (see auto-shutdown.py)"
    echo "   - Trigger: Pub/Sub budget-alerts topic"
    echo "   - Action: Scale Cloud Run to 0 instances"
    echo ""
    echo "4. Budget will auto-recover on 1st of next month"
    echo ""
fi

# Set up resource quotas
print_status "Recommended Resource Limits"
echo ""
echo "Set these limits in your Cloud Run service:"
echo ""
echo "gcloud run services update valhalla-ai-hub \\"
echo "  --region=us-central1 \\"
echo "  --min-instances=0 \\"
echo "  --max-instances=3 \\"
echo "  --memory=1Gi \\"
echo "  --cpu=1 \\"
echo "  --timeout=300s \\"
echo "  --concurrency=10 \\"
echo "  --set-env-vars=MAX_DAILY_REQUESTS=100,MAX_MONTHLY_COST=80"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Budget Protection Summary${NC}"
echo ""
echo "✓ Budget Configured: \$${MONTHLY_BUDGET}/month"
echo "✓ Alerts at: 25%, 50%, 75%, 95%, 100%"
echo "✓ Project: $PROJECT_ID"
echo "✓ Billing Account: $BILLING_ACCOUNT"
echo ""
echo -e "${YELLOW}IMPORTANT: Complete setup in GCP Console${NC}"
echo "  → https://console.cloud.google.com/billing/$BILLING_ACCOUNT/budgets"
echo ""
echo -e "${YELLOW}Monitor Costs:${NC}"
echo "  → https://console.cloud.google.com/billing/reports"
echo ""
echo -e "${YELLOW}Check Current Spend:${NC}"
echo "  ./check-costs.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_success "Budget alert configuration complete!"
echo ""
print_warning "Remember: Create the budget in GCP Console to activate alerts"
echo ""
