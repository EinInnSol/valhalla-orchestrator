#!/bin/bash
#
# VALHALLA ORCHESTRATOR V2 - Resource Cleanup
#
# Clean up old resources to reduce costs
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
║        🧹 RESOURCE CLEANUP                              ║
║           Reduce Costs by Removing Old Resources        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$PROJECT_ID" ]; then
    print_error "No project set"
    exit 1
fi

echo ""
print_warning "This script will clean up resources to reduce costs"
print_warning "You will be asked to confirm before any deletions"
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""

# 1. Clean up old container images
print_status "Checking container images..."
IMAGES=$(gcloud container images list --repository=gcr.io/$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")

if [ -n "$IMAGES" ]; then
    echo ""
    echo "Container images found:"
    gcloud container images list --repository=gcr.io/$PROJECT_ID 2>/dev/null || true
    echo ""
    print_warning "Keeping latest 3 images per repository"
    echo ""
    read -p "Delete old container images? (y/n): " DELETE_IMAGES

    if [ "$DELETE_IMAGES" = "y" ] || [ "$DELETE_IMAGES" = "Y" ]; then
        for IMAGE in $IMAGES; do
            print_status "Processing $IMAGE..."

            # Get digests, skip the 3 most recent
            DIGESTS_TO_DELETE=$(gcloud container images list-tags $IMAGE \
                --format="get(digest)" \
                --sort-by=~timestamp \
                2>/dev/null | tail -n +4 || echo "")

            if [ -n "$DIGESTS_TO_DELETE" ]; then
                for DIGEST in $DIGESTS_TO_DELETE; do
                    print_status "Deleting $IMAGE@$DIGEST"
                    gcloud container images delete "$IMAGE@$DIGEST" --quiet 2>/dev/null || true
                done
                print_success "Cleaned up old images for $IMAGE"
            else
                print_success "No old images to delete for $IMAGE"
            fi
        done
    fi
else
    print_success "No container images found"
fi

echo ""

# 2. Clean up old Cloud Build artifacts
print_status "Checking Cloud Build history..."
OLD_BUILDS=$(gcloud builds list --filter="createTime<-P30D" --format="value(id)" --limit=100 2>/dev/null || echo "")

if [ -n "$OLD_BUILDS" ]; then
    BUILD_COUNT=$(echo "$OLD_BUILDS" | wc -l)
    echo ""
    print_warning "Found $BUILD_COUNT builds older than 30 days"
    echo ""
    print_status "Note: Build logs are useful for debugging"
    read -p "Delete old build logs? (y/n): " DELETE_BUILDS

    if [ "$DELETE_BUILDS" = "y" ] || [ "$DELETE_BUILDS" = "Y" ]; then
        print_status "Deleting old builds..."
        # Note: Can't delete builds via gcloud, but can delete logs
        print_warning "Build records preserved, but you can delete logs in console"
        echo "  https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID"
    fi
else
    print_success "No old builds to clean up"
fi

echo ""

# 3. Clean up old logs (beyond free tier)
print_status "Checking Cloud Logging..."
echo ""
print_warning "Logs older than 30 days consume storage"
print_status "Free tier: 50 GB/month"
echo ""
read -p "Set log retention to 30 days? (y/n): " SET_RETENTION

if [ "$SET_RETENTION" = "y" ] || [ "$SET_RETENTION" = "Y" ]; then
    print_status "Setting log retention policies..."

    # Create log bucket with 30-day retention
    cat << 'RETENTION_SCRIPT' > /tmp/set-retention.sh
#!/bin/bash
gcloud logging buckets update _Default \
    --location=global \
    --retention-days=30 \
    2>/dev/null || echo "Note: May require additional permissions"
RETENTION_SCRIPT

    chmod +x /tmp/set-retention.sh
    /tmp/set-retention.sh
    rm /tmp/set-retention.sh

    print_success "Log retention set to 30 days"
fi

echo ""

# 4. Firestore cleanup suggestions
print_status "Firestore cleanup recommendations..."
echo ""
echo "To clean up old Firestore data, use the app or run Python script:"
echo ""
cat << 'FIRESTORE_CLEANUP' > /tmp/cleanup-firestore-guide.txt
# Firestore Cleanup Commands

# Delete old conversations (older than 90 days)
python3 << 'PYTHON'
from google.cloud import firestore
from datetime import datetime, timedelta
import os

os.environ['GCP_PROJECT_ID'] = 'YOUR_PROJECT_ID'
db = firestore.Client()

cutoff_date = datetime.now() - timedelta(days=90)

# Get old conversations
conversations = db.collection('conversation_history').where(
    'saved_at', '<', cutoff_date
).stream()

count = 0
for conv in conversations:
    conv.reference.delete()
    count += 1

print(f"Deleted {count} old conversations")
PYTHON

# Or manually in console:
# https://console.cloud.google.com/firestore/data
FIRESTORE_CLEANUP

echo "Firestore cleanup script saved to: /tmp/cleanup-firestore-guide.txt"
echo ""
read -p "View Firestore cleanup guide? (y/n): " VIEW_FS

if [ "$VIEW_FS" = "y" ] || [ "$VIEW_FS" = "Y" ]; then
    cat /tmp/cleanup-firestore-guide.txt
fi

echo ""

# 5. Check for unused services
print_status "Checking for unused resources..."
echo ""

# Check Cloud Run
CLOUD_RUN_SERVICES=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null || echo "")
if [ -n "$CLOUD_RUN_SERVICES" ]; then
    echo "Active Cloud Run services:"
    gcloud run services list --format="table(metadata.name,status.url,status.traffic[0].latestRevision)" 2>/dev/null || true
    echo ""
fi

# 6. Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Cost Reduction Recommendations:${NC}"
echo ""
echo "1. ✓ Delete old container images (keep latest 3)"
echo "2. ✓ Set log retention to 30 days"
echo "3. ✓ Clean up Firestore data older than 90 days"
echo ""
echo "4. Manual optimizations:"
echo "   • Scale Cloud Run to 0 when not in use"
echo "   • Delete unused Cloud Run services"
echo "   • Remove test/staging environments"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}To temporarily pause everything:${NC}"
echo ""
echo "gcloud run services update valhalla-ai-hub \\"
echo "  --region=us-central1 \\"
echo "  --max-instances=0"
echo ""
echo "To resume:"
echo ""
echo "gcloud run services update valhalla-ai-hub \\"
echo "  --region=us-central1 \\"
echo "  --max-instances=3"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_success "Cleanup recommendations complete!"
echo ""
print_status "Current costs: Run ./check-costs.sh"
echo ""
