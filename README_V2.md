# ⚡ VALHALLA ORCHESTRATOR V2

**Your Cloud-Native AI Command Center** - Enterprise-grade Streamlit app with Vertex AI Claude integration

Built for GCP with zero API costs, comprehensive monitoring, and one-click deployment.

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites

- ✅ GCP account with billing enabled
- ✅ `gcloud` CLI installed ([Get it here](https://cloud.google.com/sdk/docs/install))
- ✅ Basic familiarity with GCP Console

### One-Click Deployment

```bash
# Clone or download the repository
git clone <your-repo-url>
cd valhalla-orchestrator

# Make the deploy script executable
chmod +x deploy-gcp.sh

# Run deployment
./deploy-gcp.sh
```

**That's it!** The script will:
1. Configure your GCP project
2. Enable all required APIs
3. Set up Firestore database
4. Create service accounts with proper permissions
5. Deploy to Cloud Run
6. Provide you with a live URL

---

## 🎯 What's New in V2

### Major Improvements Over V1

| Feature | V1 | V2 |
|---------|----|----|
| **Error Handling** | Basic | Comprehensive with retry logic |
| **Monitoring** | None | Cloud Logging integration |
| **Cost Tracking** | Manual | Automatic with usage stats |
| **Deployment** | Manual steps | One-click script |
| **CI/CD** | None | Cloud Build configuration |
| **Health Checks** | None | Automated diagnostics |
| **Security** | Basic | Non-root containers, IAM best practices |
| **Documentation** | Minimal | Comprehensive |
| **Configuration** | Hardcoded | Environment-based with validation |

### Key Features

✨ **Enhanced Architecture**
- Modular design with separation of concerns
- Comprehensive error handling and logging
- Automatic retry logic for API calls
- Local caching for offline support

⚡ **One-Click Deployment**
- Automated GCP setup and configuration
- API enablement automation
- Service account creation with least privilege
- Environment validation

📊 **Cost Monitoring**
- Real-time cost tracking
- Usage statistics dashboard
- Request counting
- Performance metrics

🔒 **Enterprise Security**
- Non-root container execution
- IAM role-based access control
- Secret Manager integration ready
- Security best practices

🛠️ **DevOps Tools**
- Cloud Build CI/CD pipeline
- Deployment verification script
- Comprehensive diagnostic tool
- Health check endpoints

---

## 📖 Architecture

### System Components

```
┌─────────────────────────────────────────────────────────┐
│                     User Browser                        │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Cloud Run (Streamlit App)                  │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │   app_v2.py │──│vertex_claude │──│context_manager│  │
│  │  (UI Layer) │  │ _v2.py       │  │_v2.py         │  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
└──────────┬──────────────────┬──────────────────┬────────┘
           │                  │                  │
           ▼                  ▼                  ▼
    ┌────────────┐   ┌──────────────┐   ┌──────────────┐
    │   Cloud    │   │  Vertex AI   │   │  Firestore   │
    │  Logging   │   │   (Claude)   │   │  (Storage)   │
    └────────────┘   └──────────────┘   └──────────────┘
```

### File Structure

```
valhalla-orchestrator/
├── app_v2.py                 # Enhanced Streamlit UI
├── vertex_claude_v2.py       # Vertex AI integration with monitoring
├── context_manager_v2.py     # Firestore manager with caching
├── deploy-gcp.sh             # One-click deployment script
├── verify-deployment.sh      # Deployment verification
├── diagnose.sh               # Diagnostic tool
├── cloudbuild.yaml           # CI/CD configuration
├── Dockerfile.optimized      # Multi-stage optimized build
├── config.yaml               # Application configuration
├── .env.example              # Environment template
├── requirements.txt          # Python dependencies
└── README_V2.md              # This file
```

---

## 💰 Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| **Vertex AI Claude** | $0 - $50 | Pay per use, ~$3-15 per 1M tokens |
| **Cloud Run** | $0 - $5 | 2M requests free, then $0.40 per 1M |
| **Firestore** | $0 - $2 | 1GB storage free, 50K reads free daily |
| **Cloud Logging** | $0 - $1 | 50GB free per month |
| **Total** | **$0 - $58/month** | Actual cost depends on usage |

**vs. Anthropic API Direct**: Saves $20-40/month for moderate usage!

---

## 🔧 Configuration

### Environment Variables

Create a `.env` file for local development:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```bash
# Required
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1

# Optional (defaults shown)
CLAUDE_MODEL=claude-3-5-sonnet@20240620
CLAUDE_MAX_TOKENS=4096
CLAUDE_TEMPERATURE=0.7
LOG_LEVEL=INFO
```

For Cloud Run, set environment variables during deployment:

```bash
gcloud run services update valhalla-ai-hub \
  --set-env-vars GCP_PROJECT_ID=your-project-id,GCP_REGION=us-central1 \
  --region us-central1
```

---

## 🛠️ Development

### Local Development

1. **Install dependencies:**

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

2. **Set up authentication:**

```bash
# Create service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=valhalla-service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=./key.json
export GCP_PROJECT_ID=your-project-id
```

3. **Run locally:**

```bash
streamlit run app_v2.py
```

### Testing Changes

```bash
# Lint code
pylint app_v2.py vertex_claude_v2.py context_manager_v2.py

# Test deployment locally with Docker
docker build -f Dockerfile.optimized -t valhalla-test .
docker run -p 8080:8080 \
  -e GCP_PROJECT_ID=your-project-id \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/key.json \
  -v $(pwd)/key.json:/app/key.json \
  valhalla-test
```

---

## 🚀 Deployment Options

### Option 1: One-Click Script (Recommended)

```bash
./deploy-gcp.sh
```

### Option 2: Cloud Build CI/CD

```bash
# Submit build
gcloud builds submit --config cloudbuild.yaml

# Set up trigger for automatic deploys on git push
gcloud builds triggers create github \
  --repo-name=valhalla-orchestrator \
  --repo-owner=YOUR_GITHUB_USERNAME \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

### Option 3: Manual gcloud

```bash
gcloud run deploy valhalla-ai-hub \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT_ID=your-project-id
```

---

## 🔍 Monitoring & Troubleshooting

### View Logs

```bash
# Real-time logs
gcloud run services logs tail valhalla-ai-hub --region us-central1

# Recent logs
gcloud run services logs read valhalla-ai-hub --region us-central1 --limit 50
```

### Run Diagnostics

```bash
# Comprehensive diagnostic check
./diagnose.sh

# Verify deployment
./verify-deployment.sh us-central1
```

### Common Issues

#### Issue: "Vertex AI not configured"

**Solution:**
1. Verify Claude is enabled in Model Garden
2. Check `GCP_PROJECT_ID` environment variable
3. Ensure service account has `aiplatform.user` role

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member=serviceAccount:valhalla-service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/aiplatform.user
```

#### Issue: "Firestore not initialized"

**Solution:**
```bash
gcloud firestore databases create \
  --location=us-central1 \
  --project=YOUR_PROJECT_ID
```

#### Issue: High costs

**Solution:**
- Check usage stats in the sidebar
- Review Cloud Logging for excessive requests
- Consider setting quota limits in GCP Console

---

## 📊 Features Deep Dive

### Cost Tracking

The V2 version includes automatic cost tracking:

- **Real-time calculation** based on token usage
- **Session statistics** in sidebar
- **Firestore logging** of all executions
- **Query capabilities** for historical analysis

### Error Handling

Comprehensive error handling includes:

- **Retry logic** with exponential backoff
- **Graceful degradation** when services are offline
- **Detailed error messages** for troubleshooting
- **Cloud Logging** integration for debugging

### Caching

Smart caching reduces API calls:

- **5-minute TTL** for project context
- **Automatic invalidation** on updates
- **Offline support** with cached data
- **Configurable** cache settings

---

## 🔒 Security Best Practices

### Implemented

- ✅ Non-root container execution
- ✅ Least privilege IAM roles
- ✅ No secrets in code or repository
- ✅ HTTPS-only communication
- ✅ Input validation
- ✅ XSRF protection enabled

### Recommended

- 🔐 Enable Identity-Aware Proxy (IAP) for production
- 🔐 Use Secret Manager for sensitive configuration
- 🔐 Set up VPC Service Controls
- 🔐 Enable Cloud Armor for DDoS protection
- 🔐 Regular security audits

---

## 🎯 Roadmap

### Planned Features

- [ ] Authentication with Google OAuth
- [ ] Multi-user support with user isolation
- [ ] Advanced analytics dashboard
- [ ] Integration with other GCP AI services
- [ ] Slack/Discord bot integration
- [ ] API endpoint for programmatic access
- [ ] Cost alerting and budget management
- [ ] A/B testing for different Claude models
- [ ] Conversation export/import
- [ ] Team collaboration features

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

---

## 🙏 Acknowledgments

- Built with [Streamlit](https://streamlit.io/)
- Powered by [Anthropic Claude](https://www.anthropic.com/) via Vertex AI
- Deployed on [Google Cloud Platform](https://cloud.google.com/)

---

## 📞 Support

### Getting Help

1. **Check the documentation** in this README
2. **Run diagnostics**: `./diagnose.sh`
3. **View logs**: `gcloud run services logs tail valhalla-ai-hub`
4. **Open an issue** on GitHub with detailed error information

### Useful Resources

- [GCP Documentation](https://cloud.google.com/docs)
- [Vertex AI Model Garden](https://cloud.google.com/vertex-ai/docs/start/explore-models)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)

---

## 🎉 Success!

Once deployed, you'll have a fully-functional AI command center with:

- 💬 Chat interface with Claude 3.5 Sonnet
- 📊 Real-time cost tracking
- 💾 Persistent conversation storage
- 🔍 Comprehensive monitoring
- 🚀 Scalable infrastructure

**Start building with your AI co-founder today!** ⚡

---

**Built with ❤️ for the 90-day bootstrap mission to $15K/month**
