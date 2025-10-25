#!/usr/bin/env python3
"""
VALHALLA ORCHESTRATOR V2 - Enhanced Command Center
Cloud-native AI partnership hub with enterprise features
"""

import streamlit as st
import os
import traceback
from datetime import datetime
from google.cloud import firestore, logging as cloud_logging
from vertex_claude import VertexClaudeV2
from context_manager import ContextManagerV2
from typing import Optional
import json

# Initialize Cloud Logging
try:
    logging_client = cloud_logging.Client()
    logging_client.setup_logging()
    import logging
    logger = logging.getLogger(__name__)
except Exception as e:
    import logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
    logger.warning(f"Cloud Logging not available: {e}")

# Page config
st.set_page_config(
    page_title="Valhalla AI Hub V2.0",
    page_icon="⚡",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Enhanced CSS with better responsiveness and dark theme
st.markdown("""
<style>
    /* Dark theme base */
    .stApp {
        background-color: #0a0e1a;
        color: #e0e0e0;
    }

    /* Sidebar styling */
    [data-testid="stSidebar"] {
        background-color: #0f1419;
        border-right: 1px solid #1a2332;
    }

    /* Project cards with improved hover effects */
    .project-card {
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
        padding: 15px;
        border-radius: 10px;
        margin: 10px 0;
        cursor: pointer;
        transition: transform 0.2s, box-shadow 0.2s;
    }

    .project-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
    }

    .project-card-building {
        background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    }

    .project-card-building:hover {
        box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
    }

    .project-card-planning {
        background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    }

    .project-card-planning:hover {
        box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    /* Status indicators */
    .status-live { color: #10b981; font-size: 0.9em; }
    .status-building { color: #8b5cf6; font-size: 0.9em; }
    .status-planning { color: #3b82f6; font-size: 0.9em; }

    /* Quick actions */
    .action-button {
        background-color: #1a2332;
        padding: 12px;
        border-radius: 8px;
        margin: 8px 0;
        border: 1px solid #2d3748;
        cursor: pointer;
        transition: all 0.2s;
    }

    .action-button:hover {
        background-color: #2d3748;
        border-color: #4a5568;
    }

    /* Usage stats */
    .usage-stat {
        display: flex;
        justify-content: space-between;
        padding: 8px 0;
        border-bottom: 1px solid #1a2332;
    }

    /* Connection indicator */
    .connection-status {
        color: #10b981;
        font-size: 0.85em;
        padding: 8px;
        background-color: rgba(16, 185, 129, 0.1);
        border-radius: 6px;
        margin-top: 10px;
    }

    .connection-error {
        color: #ef4444;
        font-size: 0.85em;
        padding: 8px;
        background-color: rgba(239, 68, 68, 0.1);
        border-radius: 6px;
        margin-top: 10px;
    }

    /* Chat messages */
    .stChatMessage {
        background-color: #1a2332;
        border-radius: 8px;
        padding: 12px;
        margin: 8px 0;
    }

    /* Enhanced buttons */
    .stButton button {
        background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
        color: white;
        border: none;
        padding: 12px 24px;
        border-radius: 8px;
        font-weight: 600;
        transition: all 0.2s;
    }

    .stButton button:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    /* Error messages */
    .error-box {
        background-color: rgba(239, 68, 68, 0.1);
        border: 1px solid #ef4444;
        border-radius: 8px;
        padding: 12px;
        margin: 12px 0;
    }

    /* Success messages */
    .success-box {
        background-color: rgba(16, 185, 129, 0.1);
        border: 1px solid #10b981;
        border-radius: 8px;
        padding: 12px;
        margin: 12px 0;
    }
</style>
""", unsafe_allow_html=True)

def initialize_session_state():
    """Initialize all session state variables with error handling"""
    try:
        if 'context_manager' not in st.session_state:
            st.session_state.context_manager = ContextManagerV2()
            logger.info("ContextManagerV2 initialized")

        if 'vertex_claude' not in st.session_state:
            st.session_state.vertex_claude = VertexClaudeV2()
            logger.info("VertexClaudeV2 initialized")

        if 'messages' not in st.session_state:
            st.session_state.messages = []

        if 'current_project' not in st.session_state:
            st.session_state.current_project = 'HAVEN Platform'

        if 'total_cost' not in st.session_state:
            st.session_state.total_cost = 0.0

        if 'request_count' not in st.session_state:
            st.session_state.request_count = 0

        if 'connection_status' not in st.session_state:
            st.session_state.connection_status = check_connections()

        return True

    except Exception as e:
        logger.error(f"Session state initialization error: {e}")
        st.error(f"⚠️ Initialization Error: {str(e)}")
        return False

def check_connections() -> dict:
    """Check all service connections"""
    status = {
        'vertex_ai': False,
        'firestore': False,
        'project_id': os.getenv('GCP_PROJECT_ID', 'Not Set')
    }

    try:
        # Check Vertex AI
        if hasattr(st.session_state, 'vertex_claude') and st.session_state.vertex_claude.model:
            status['vertex_ai'] = True
    except:
        pass

    try:
        # Check Firestore
        if hasattr(st.session_state, 'context_manager') and st.session_state.context_manager.db:
            status['firestore'] = True
    except:
        pass

    return status

def render_sidebar():
    """Render enhanced sidebar with status checks"""
    with st.sidebar:
        st.markdown("# ⚡ VALHALLA V2")
        st.markdown("**AI Partnership Hub**")

        # Connection status
        status = st.session_state.connection_status
        if status['vertex_ai'] and status['firestore']:
            st.markdown("<div class='connection-status'>✓ All Systems Online</div>", unsafe_allow_html=True)
        else:
            st.markdown("<div class='connection-error'>⚠ Configuration Needed</div>", unsafe_allow_html=True)
            if not status['vertex_ai']:
                st.warning("Vertex AI not connected")
            if not status['firestore']:
                st.warning("Firestore not connected")

        st.markdown("---")
        st.markdown("### PROJECTS")

        # Project list
        projects = [
            ("🏠", "HAVEN Platform", "Live", "project-card"),
            ("🚀", "First Contact", "Building", "project-card-building"),
            ("🌐", "Company Site", "Planning", "project-card-planning")
        ]

        for icon, name, status_text, card_class in projects:
            col1, col2 = st.columns([1, 4])
            with col1:
                st.markdown(f"<div style='font-size: 2em;'>{icon}</div>", unsafe_allow_html=True)
            with col2:
                if st.button(f"{name}", key=f"proj_{name}", use_container_width=True):
                    st.session_state.current_project = name
                    logger.info(f"Switched to project: {name}")
                status_class = f"status-{status_text.lower()}"
                st.markdown(f"<span class='{status_class}'>⚡ {status_text}</span>", unsafe_allow_html=True)

        if st.button("➕ New Project", use_container_width=True):
            st.session_state.show_new_project = True

        st.markdown("---")
        st.markdown("### QUICK ACTIONS")

        if st.button("📊 View Analytics", use_container_width=True):
            st.info("Analytics dashboard coming soon...")

        if st.button("⚙️ Settings", use_container_width=True):
            st.session_state.show_settings = True

        if st.button("🔄 Refresh Status", use_container_width=True):
            st.session_state.connection_status = check_connections()
            st.rerun()

        st.markdown("---")
        st.markdown("### 💵 Today's Usage")

        st.markdown(f"""
        <div class='usage-stat'>
            <span>Total Cost:</span>
            <span style='color: #10b981;'>${st.session_state.total_cost:.4f}</span>
        </div>
        <div class='usage-stat'>
            <span>Requests:</span>
            <span>{st.session_state.request_count}</span>
        </div>
        <div class='usage-stat'>
            <span>Model:</span>
            <span>Claude 3.5 Sonnet</span>
        </div>
        <div class='usage-stat'>
            <span>Project:</span>
            <span style='font-size: 0.8em;'>{status['project_id'][:20]}...</span>
        </div>
        """, unsafe_allow_html=True)

        st.markdown("---")
        st.markdown("### 🔗 Quick Links")
        st.markdown("[📖 Documentation](https://github.com)")
        st.markdown("[🐛 Report Issue](https://github.com)")
        st.markdown("[💡 Request Feature](https://github.com)")

def render_main_content():
    """Render main chat interface"""
    col1, col2, col3 = st.columns([3, 1, 1])
    with col1:
        st.markdown(f"## {st.session_state.current_project}")
    with col2:
        if st.button("💾 Save", use_container_width=True):
            try:
                st.session_state.context_manager.save_conversation(
                    project=st.session_state.current_project,
                    messages=st.session_state.messages
                )
                st.success("Saved!")
                logger.info("Conversation saved")
            except Exception as e:
                st.error(f"Save failed: {str(e)}")
                logger.error(f"Save error: {e}")
    with col3:
        if st.button("🗑️ Clear", use_container_width=True):
            st.session_state.messages = []
            st.rerun()

    # Initialize message
    if not st.session_state.messages:
        welcome_msg = f"""⚡ **Valhalla V2 AI Hub Initialized**

Connected to **{st.session_state.current_project}**

I'm Claude, your AI co-founder. How can I help you build today?

**Quick Commands:**
- Ask about project status
- Request code generation
- Discuss architecture
- Get deployment help
"""
        st.session_state.messages.append({
            "role": "assistant",
            "content": welcome_msg
        })

    # Display chat messages
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Chat input
    user_input = st.chat_input(f"Chat with Claude about {st.session_state.current_project}...")

    if user_input:
        handle_user_input(user_input)

def handle_user_input(user_input: str):
    """Handle user input with comprehensive error handling"""
    # Add user message
    st.session_state.messages.append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)

    # Get response from Vertex AI Claude
    with st.chat_message("assistant"):
        with st.spinner("🤔 Claude is thinking..."):
            try:
                # Load context for current project
                context = st.session_state.context_manager.get_project_context(
                    st.session_state.current_project
                )

                # Route to Vertex AI Claude
                response = st.session_state.vertex_claude.chat(
                    user_input,
                    context=context,
                    conversation_history=st.session_state.messages
                )

                # Update usage stats
                st.session_state.request_count += 1
                st.session_state.total_cost += st.session_state.vertex_claude.last_request_cost

                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})

                # Auto-save conversation to Firestore
                try:
                    st.session_state.context_manager.save_conversation(
                        project=st.session_state.current_project,
                        messages=st.session_state.messages
                    )
                    logger.info(f"Conversation auto-saved for {st.session_state.current_project}")
                except Exception as save_error:
                    logger.warning(f"Auto-save failed: {save_error}")

            except Exception as e:
                error_msg = f"""❌ **Error communicating with Claude**

**Error:** {str(e)}

**Troubleshooting:**
1. Check that Vertex AI is properly configured
2. Verify GCP_PROJECT_ID environment variable is set
3. Ensure Claude is enabled in Vertex AI Model Garden
4. Check service account permissions

**Details:**
```
{traceback.format_exc()}
```
"""
                st.error(error_msg)
                logger.error(f"Chat error: {e}\n{traceback.format_exc()}")
                st.session_state.messages.append({"role": "assistant", "content": error_msg})

def main():
    """Main application entry point"""
    try:
        # Initialize session state
        if not initialize_session_state():
            st.error("Failed to initialize application. Please check configuration.")
            return

        # Render UI
        render_sidebar()
        render_main_content()

        # Footer
        st.markdown("---")
        col1, col2 = st.columns(2)
        with col1:
            st.markdown("💡 **Tip:** Using Vertex AI Claude - Zero API costs with your GCP credits!")
        with col2:
            st.markdown(f"🕐 Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    except Exception as e:
        st.error(f"Application Error: {str(e)}")
        logger.error(f"Main app error: {e}\n{traceback.format_exc()}")
        st.code(traceback.format_exc())

if __name__ == "__main__":
    main()
