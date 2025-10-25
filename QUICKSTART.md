# ⚡ Valhalla Orchestrator V2 - Quick Start Guide

**Get your AI command center running in 5 minutes!**

---

## 🎯 Before You Start

Make sure you have:

- [ ] A GCP account with billing enabled
- [ ] The `gcloud` CLI installed ([Install guide](https://cloud.google.com/sdk/docs/install))
- [ ] Terminal/command prompt access

---

## 🚀 3-Step Deployment

### Step 1: Get the Code

```bash
# Clone or download this repository
cd valhalla-orchestrator

# Verify you have the deployment script
ls deploy-gcp.sh
```

### Step 2: Run the Deploy Script

```bash
# Make script executable (if needed)
chmod +x deploy-gcp.sh

# Run deployment
./deploy-gcp.sh
```

**Follow the prompts:**

1. Enter your GCP Project ID (or confirm current project)
2. Choose region (press Enter for default: us-central1)
3. Wait while APIs are enabled
4. **IMPORTANT**: When prompted, visit the Vertex AI Model Garden link
5. Enable "Claude 3.5 Sonnet" in the Model Garden
6. Press Enter to continue deployment

### Step 3: Open Your App

The script will output a URL like:

```
https://valhalla-ai-hub-xxxxx-uc.a.run.app
```

**Click it and start chatting with Claude!**

---

## ✅ Verify It's Working

Run the verification script:

```bash
./verify-deployment.sh
```

You should see:
- ✓ Service found
- ✓ Service is responding
- ✓ Firestore database found
- ✓ APIs enabled

---

## 🎨 What You'll See

When you open the app, you'll get:

```
┌──────────────────────────────────────────────┐
│  VALHALLA V2 - AI Partnership Hub            │
├──────────────────────────────────────────────┤
│                                              │
│  Sidebar:                                    │
│  • Project switcher (HAVEN, First Contact)  │
│  • Quick actions                             │
│  • Usage stats ($0.00 to start)              │
│  • Connection status                         │
│                                              │
│  Main Area:                                  │
│  • Chat interface with Claude                │
│  • Rich markdown formatting                  │
│  • Code syntax highlighting                  │
│                                              │
└──────────────────────────────────────────────┘
```

---

## 💡 Try These Commands

Chat with Claude about:

1. **"Explain the HAVEN Platform project"**
   - Claude will use the pre-loaded project context

2. **"Help me design a user authentication system"**
   - Get architecture advice and code examples

3. **"Show me how to deploy a FastAPI app on Cloud Run"**
   - Receive step-by-step deployment instructions

4. **"What should I build first for the 90-day mission?"**
   - Strategic advice based on mission context

---

## 🔧 Troubleshooting

### Issue: "Vertex AI not configured"

**Fix:**
1. Go to [Vertex AI Model Garden](https://console.cloud.google.com/vertex-ai/model-garden)
2. Search for "Claude"
3. Click "Claude 3.5 Sonnet"
4. Click "Enable"
5. Refresh your Valhalla app

### Issue: "Firestore error"

**Fix:**
```bash
# Initialize Firestore manually
gcloud firestore databases create --location=us-central1
```

### Issue: Deployment failed

**Fix:**
```bash
# Run diagnostics
./diagnose.sh

# Check what's wrong
# Re-run deployment
./deploy-gcp.sh
```

### Still having issues?

```bash
# Check service logs
gcloud run services logs tail valhalla-ai-hub --region us-central1

# Get detailed service info
gcloud run services describe valhalla-ai-hub --region us-central1
```

---

## 📊 Understanding Costs

Your usage stats appear in the sidebar:

```
💵 Today's Usage
Total Cost: $0.0000
Requests: 0
Model: Claude 3.5 Sonnet
```

**Cost breakdown:**
- First chat: ~$0.002 - $0.01
- Typical conversation: ~$0.01 - $0.05
- Heavy daily use: ~$1 - $5/month

**Way cheaper than Anthropic API!** 🎉

---

## 🎯 Next Steps

### 1. Customize Your Projects

Edit the sidebar projects by modifying Firestore data:

```bash
# Access Firestore
gcloud firestore databases list

# Add/edit projects through GCP Console:
# https://console.cloud.google.com/firestore
```

### 2. Set Up Cost Alerts

```bash
# Create budget alert in GCP Console
# https://console.cloud.google.com/billing/budgets
```

### 3. Enable Authentication (Optional)

Add Google OAuth:

```bash
# Update Cloud Run service
gcloud run services update valhalla-ai-hub \
  --no-allow-unauthenticated \
  --region us-central1

# Users will need to authenticate via Google
```

### 4. Set Up CI/CD (Optional)

For automatic deployments on git push:

```bash
# Configure Cloud Build trigger
gcloud builds triggers create github \
  --repo-name=valhalla-orchestrator \
  --repo-owner=YOUR_GITHUB_USER \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

---

## 🔗 Useful Commands

```bash
# View live logs
gcloud run services logs tail valhalla-ai-hub --region us-central1

# Update the app (redeploy)
./deploy-gcp.sh

# Delete the deployment
gcloud run services delete valhalla-ai-hub --region us-central1

# Check service status
gcloud run services describe valhalla-ai-hub --region us-central1

# Run diagnostics
./diagnose.sh

# Verify deployment
./verify-deployment.sh
```

---

## 📚 Learn More

- **Full Documentation**: See `README_V2.md`
- **Architecture Details**: See `README_V2.md` > Architecture section
- **Development Guide**: See `README_V2.md` > Development section

---

## 🎉 You're Ready!

Your Valhalla Orchestrator is now:
- ✅ Deployed on Cloud Run
- ✅ Connected to Vertex AI Claude
- ✅ Storing data in Firestore
- ✅ Tracking costs automatically
- ✅ Ready for production use

**Happy building!** ⚡

---

**Questions?** Check `README_V2.md` or run `./diagnose.sh` for help.

**Found a bug?** Please open an issue on GitHub.

**Want to contribute?** Pull requests welcome!
