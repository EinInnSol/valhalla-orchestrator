#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - One-Click GCP Deployment
#
# This script automates the complete deployment process:
# 1. GCP project setup and API enablement
# 2. Service account creation with proper permissions
# 3. Firestore database initialization
# 4. Cloud Run deployment
# 5. Environment configuration
#
# Usage: ./deploy-gcp.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="valhalla-orchestrator"
REGION="us-central1"
SERVICE_NAME="valhalla-ai-hub"

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        ⚡ VALHALLA ORCHESTRATOR V2                      ║
║           One-Click GCP Deployment                       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to print status messages
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists gcloud; then
    print_error "gcloud CLI not found. Please install it from:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if ! command_exists docker; then
    print_warning "Docker not found. It's optional but recommended for local testing."
fi

print_success "Prerequisites check complete"

# Get GCP Project ID
echo ""
print_status "GCP Project Configuration"
echo ""

# Try to get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -n "$CURRENT_PROJECT" ]; then
    echo "Current project: $CURRENT_PROJECT"
    read -p "Use this project? (y/n): " USE_CURRENT
    if [ "$USE_CURRENT" = "y" ] || [ "$USE_CURRENT" = "Y" ]; then
        PROJECT_ID=$CURRENT_PROJECT
    else
        read -p "Enter your GCP Project ID: " PROJECT_ID
    fi
else
    read -p "Enter your GCP Project ID: " PROJECT_ID
fi

# Validate project ID
if [ -z "$PROJECT_ID" ]; then
    print_error "Project ID cannot be empty"
    exit 1
fi

print_status "Setting project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Set region
echo ""
read -p "Enter region (default: us-central1): " USER_REGION
REGION=${USER_REGION:-$REGION}

print_success "Configuration set: $PROJECT_ID in $REGION"

# Enable required APIs
echo ""
print_status "Enabling required GCP APIs..."

APIS=(
    "run.googleapis.com"
    "firestore.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "aiplatform.googleapis.com"
    "logging.googleapis.com"
    "secretmanager.googleapis.com"
)

for api in "${APIS[@]}"; do
    print_status "Enabling $api..."
    gcloud services enable $api --project=$PROJECT_ID
done

print_success "All APIs enabled"

# Initialize Firestore
echo ""
print_status "Initializing Firestore..."

# Check if Firestore is already initialized
FIRESTORE_STATUS=$(gcloud firestore databases list --project=$PROJECT_ID 2>/dev/null | grep -c "(default)" || echo "0")

if [ "$FIRESTORE_STATUS" = "0" ]; then
    print_status "Creating Firestore database in Native mode..."
    gcloud firestore databases create --location=$REGION --project=$PROJECT_ID
    print_success "Firestore database created"
else
    print_success "Firestore already initialized"
fi

# Check Vertex AI Claude availability
echo ""
print_status "Checking Vertex AI Model Garden..."
echo ""
print_warning "IMPORTANT: Claude must be enabled in Vertex AI Model Garden"
echo ""
echo "Please follow these steps:"
echo "1. Go to: https://console.cloud.google.com/vertex-ai/model-garden"
echo "2. Search for 'Claude'"
echo "3. Enable 'Claude 3.5 Sonnet' model"
echo "4. Accept the terms of service"
echo ""
read -p "Press ENTER when you've enabled Claude in Vertex AI..."

# Create service account
echo ""
print_status "Setting up service account..."

SA_NAME="valhalla-service-account"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if service account exists
SA_EXISTS=$(gcloud iam service-accounts list --project=$PROJECT_ID --filter="email:${SA_EMAIL}" --format="value(email)" | wc -l)

if [ "$SA_EXISTS" = "0" ]; then
    print_status "Creating service account: $SA_NAME"
    gcloud iam service-accounts create $SA_NAME \
        --display-name="Valhalla Orchestrator Service Account" \
        --project=$PROJECT_ID
    print_success "Service account created"
else
    print_success "Service account already exists"
fi

# Grant necessary roles
print_status "Granting IAM roles..."

ROLES=(
    "roles/aiplatform.user"
    "roles/datastore.user"
    "roles/logging.logWriter"
)

for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role" \
        --condition=None \
        >/dev/null 2>&1
done

print_success "IAM roles granted"

# Build and deploy to Cloud Run
echo ""
print_status "Building and deploying to Cloud Run..."

# Rename v2 files to main files for deployment
cp app_v2.py app_deploy.py
cp vertex_claude_v2.py vertex_claude.py
cp context_manager_v2.py context_manager.py

# Update imports in app_deploy.py
sed -i 's/VertexClaudeV2/VertexClaude/g' app_deploy.py
sed -i 's/ContextManagerV2/ContextManager/g' app_deploy.py
sed -i 's/vertex_claude_v2/vertex_claude/g' app_deploy.py
sed -i 's/context_manager_v2/context_manager/g' app_deploy.py

# Rename classes in the files
sed -i 's/class VertexClaudeV2/class VertexClaude/g' vertex_claude.py
sed -i 's/class ContextManagerV2/class ContextManager/g' context_manager.py

# Update requirements
cat > requirements_deploy.txt << EOF
streamlit==1.32.0
google-cloud-aiplatform==1.49.0
google-cloud-firestore==2.15.0
google-cloud-logging==3.8.0
anthropic==0.23.1
python-dotenv==1.0.1
requests==2.31.0
EOF

# Create Dockerfile for deployment
cat > Dockerfile.deploy << EOF
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    gcc \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements_deploy.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app_deploy.py app.py
COPY vertex_claude.py .
COPY context_manager.py .

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl --fail http://localhost:8080/_stcore/health || exit 1

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0", "--server.headless=true", "--server.runOnSave=false", "--browser.gatherUsageStats=false"]
EOF

# Deploy to Cloud Run
print_status "Deploying to Cloud Run (this may take a few minutes)..."

gcloud run deploy $SERVICE_NAME \
    --source . \
    --dockerfile Dockerfile.deploy \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --service-account $SA_EMAIL \
    --set-env-vars "GCP_PROJECT_ID=$PROJECT_ID,GCP_REGION=$REGION" \
    --memory 1Gi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --project $PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format="value(status.url)")

# Cleanup temporary files
rm -f app_deploy.py requirements_deploy.txt Dockerfile.deploy

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              🎉 DEPLOYMENT SUCCESSFUL! 🎉               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
print_success "Your Valhalla Orchestrator is now live!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "🌐 ${GREEN}Application URL:${NC}"
echo "   $SERVICE_URL"
echo ""
echo -e "📊 ${BLUE}Project Details:${NC}"
echo "   Project ID: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Service: $SERVICE_NAME"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Open the application URL above in your browser"
echo "2. Verify that Vertex AI Claude is working"
echo "3. Start chatting with your AI co-founder!"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo ""
echo "  View logs:"
echo "  gcloud run services logs tail $SERVICE_NAME --region $REGION"
echo ""
echo "  Update deployment:"
echo "  ./deploy-gcp.sh"
echo ""
echo "  Delete deployment:"
echo "  gcloud run services delete $SERVICE_NAME --region $REGION"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_success "Setup complete! Happy building! ⚡"
echo ""
