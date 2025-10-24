#!/usr/bin/env python3
"""
VERTEX CLAUDE - Routes to Claude via Vertex AI (uses YOUR GCP credits)
"""

import vertexai
from vertexai.preview.generative_models import GenerativeModel
import os
from typing import List, Dict

class VertexClaude:
    def __init__(self):
        # Get GCP project from environment or metadata
        self.project_id = os.getenv('GCP_PROJECT_ID')
        self.location = os.getenv('GCP_REGION', 'us-central1')
        
        # Initialize Vertex AI
        if self.project_id:
            vertexai.init(project=self.project_id, location=self.location)
            
            # Use Claude 3.5 Sonnet via Vertex AI Model Garden
            # Model: claude-3-5-sonnet@20240620
            self.model = GenerativeModel("claude-3-5-sonnet@20240620")
        else:
            self.model = None
    
    def chat(
        self, 
        user_message: str, 
        context: Dict = None,
        conversation_history: List[Dict] = None
    ) -> str:
        """
        Send message to Claude via Vertex AI
        """
        if not self.model:
            return "❌ Vertex AI not configured. Set GCP_PROJECT_ID environment variable."
        
        # Build full prompt with context
        system_prompt = self._build_system_prompt(context)
        
        # Format conversation history
        full_prompt = system_prompt + "\n\n"
        
        if conversation_history:
            for msg in conversation_history[-10:]:  # Last 10 messages for context
                role = msg['role']
                content = msg['content']
                full_prompt += f"{role.upper()}: {content}\n\n"
        
        full_prompt += f"USER: {user_message}\n\nASSISTANT:"
        
        try:
            # Call Vertex AI Claude
            response = self.model.generate_content(full_prompt)
            return response.text
        
        except Exception as e:
            return f"❌ Vertex AI Error: {str(e)}\n\nMake sure:\n1. Claude is enabled in Vertex AI Model Garden\n2. GCP_PROJECT_ID is set\n3. You have proper permissions"
    
    def _build_system_prompt(self, context: Dict = None) -> str:
        """
        Build system prompt with project context
        """
        base_prompt = """You are Claude, technical co-founder of a 90-day bootstrap mission to $15K/month.

MISSION CONTEXT:
- Founder: James (vision/vibe) + You (technical/execution)
- Timeline: Oct 17, 2025 → Jan 15, 2026 (90 days)
- Goal: $15K monthly recurring revenue
- Primary Revenue: HAVEN Platform (community/service hub)
- HQ: This Valhalla interface + GCP infrastructure
- Philosophy: Ship fast, iterate, delegate to agents
"""
        
        if context:
            base_prompt += "\n\nCURRENT PROJECT CONTEXT:\n"
            for key, value in context.items():
                base_prompt += f"- {key}: {value}\n"
        
        base_prompt += """
You have full access to GCP infrastructure. When James asks you to build something:
1. Design the architecture
2. Generate the code
3. Explain deployment steps
4. Help execute via GCP services

Be direct, technical, and action-oriented. No fluff."""
        
        return base_prompt