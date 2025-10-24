#!/usr/bin/env python3
"""
VALHALLA ORCHESTRATOR - Command Center
Routes commands to Vertex AI Claude using YOUR GCP credits
"""

import streamlit as st
import os
from datetime import datetime
from google.cloud import firestore
from vertex_claude import VertexClaude
from context_manager import ContextManager

# Page config
st.set_page_config(
    page_title="Valhalla AI Partnership Hub V1.0",
    page_icon="⚡",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS matching your screenshot
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
    
    /* Project cards */
    .project-card {
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
        padding: 15px;
        border-radius: 10px;
        margin: 10px 0;
        cursor: pointer;
    }
    
    .project-card-building {
        background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
    }
    
    .project-card-planning {
        background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    }
    
    /* Status indicators */
    .status-live {
        color: #10b981;
        font-size: 0.9em;
    }
    
    .status-building {
        color: #8b5cf6;
        font-size: 0.9em;
    }
    
    .status-planning {
        color: #3b82f6;
        font-size: 0.9em;
    }
    
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
    }
    
    /* Chat input */
    .stTextInput input {
        background-color: #1a2332 !important;
        border: 1px solid #2d3748 !important;
        color: #e0e0e0 !important;
    }
    
    /* Send button */
    .stButton button {
        background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
        color: white;
        border: none;
        padding: 12px 24px;
        border-radius: 8px;
        font-weight: 600;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'context_manager' not in st.session_state:
    st.session_state.context_manager = ContextManager()
if 'vertex_claude' not in st.session_state:
    st.session_state.vertex_claude = VertexClaude()
if 'messages' not in st.session_state:
    st.session_state.messages = []
if 'current_project' not in st.session_state:
    st.session_state.current_project = 'HAVEN Platform'

# Sidebar
with st.sidebar:
    st.markdown("# ⚡ VALHALLA")
    st.markdown("**AI Partnership Hub**")
    
    st.markdown("---")
    st.markdown("### PROJECTS")
    
    # Project list
    projects = [
        ("🏠", "HAVEN Platform", "Live", "project-card"),
        ("🚀", "First Contact", "Building", "project-card-building"),
        ("🌐", "Company Site", "Planning", "project-card-planning")
    ]
    
    for icon, name, status, card_class in projects:
        col1, col2 = st.columns([1, 4])
        with col1:
            st.markdown(f"<div style='font-size: 2em;'>{icon}</div>", unsafe_allow_html=True)
        with col2:
            if st.button(f"{name}", key=f"proj_{name}", use_container_width=True):
                st.session_state.current_project = name
            status_class = f"status-{status.lower()}"
            st.markdown(f"<span class='{status_class}'>⚡ {status}</span>", unsafe_allow_html=True)
    
    if st.button("➕ New Project", use_container_width=True):
        st.session_state.show_new_project = True
    
    st.markdown("---")
    st.markdown("### QUICK ACTIONS")
    
    if st.button("</> Open Editor", use_container_width=True):
        st.info("Opening code editor...")
    
    if st.button("🚀 Deploy Project", use_container_width=True):
        st.info("Starting deployment...")
    
    if st.button("⚙️ Configuration", use_container_width=True):
        st.info("Opening configuration...")
    
    st.markdown("---")
    st.markdown("### 💵 Today's Usage")
    
    st.markdown("""
    <div class='usage-stat'>
        <span>Total Cost:</span>
        <span style='color: #10b981;'>$0.0000</span>
    </div>
    <div class='usage-stat'>
        <span>Requests:</span>
        <span>0</span>
    </div>
    <div class='usage-stat'>
        <span>Model:</span>
        <span>Sonnet 4</span>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("<div class='connection-status'>● Vertex AI Connected</div>", unsafe_allow_html=True)

# Main content area
col1, col2 = st.columns([3, 1])
with col1:
    st.markdown(f"## {st.session_state.current_project}")
with col2:
    if st.button("Clear Chat", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

# Initialize message
if not st.session_state.messages:
    st.session_state.messages.append({
        "role": "assistant",
        "content": "⚡ Valhalla AI Partnership Hub initialized. Claude is ready to collaborate."
    })

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# Chat input
user_input = st.chat_input(f"Ask Claude about {st.session_state.current_project}...")

if user_input:
    # Add user message
    st.session_state.messages.append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)
    
    # Get response from Vertex AI Claude
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
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
            
            st.markdown(response)
            st.session_state.messages.append({"role": "assistant", "content": response})
            
            # Save conversation to Firestore
            st.session_state.context_manager.save_conversation(
                project=st.session_state.current_project,
                messages=st.session_state.messages
            )

# Footer tip
st.markdown("---")
st.markdown("💡 **Tip:** Using Vertex AI Claude with YOUR GCP credits - no API costs!")