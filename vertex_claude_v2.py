#!/usr/bin/env python3
"""
VERTEX CLAUDE V2 - Enhanced Claude integration with monitoring
Routes to Claude via Vertex AI with comprehensive error handling and cost tracking
"""

import vertexai
from vertexai.preview.generative_models import GenerativeModel, GenerationConfig
import os
from typing import List, Dict, Optional
import logging
from datetime import datetime
import time

logger = logging.getLogger(__name__)

class VertexClaudeV2:
    """
    Enhanced Vertex AI Claude wrapper with:
    - Comprehensive error handling
    - Cost tracking
    - Request monitoring
    - Retry logic
    - Performance metrics
    """

    # Pricing per 1K tokens (approximate)
    PRICING = {
        'input': 0.003,   # $3 per 1M input tokens
        'output': 0.015,  # $15 per 1M output tokens
    }

    def __init__(self):
        """Initialize Vertex AI with environment configuration"""
        self.project_id = os.getenv('GCP_PROJECT_ID')
        self.location = os.getenv('GCP_REGION', 'us-central1')
        self.model_name = os.getenv('CLAUDE_MODEL', 'claude-3-5-sonnet@20240620')

        self.model = None
        self.last_request_cost = 0.0
        self.total_requests = 0
        self.total_cost = 0.0
        self.last_response_time = 0.0

        # Initialize Vertex AI
        if self.project_id:
            try:
                vertexai.init(project=self.project_id, location=self.location)
                self.model = GenerativeModel(self.model_name)
                logger.info(f"Vertex AI initialized: {self.project_id}/{self.location}/{self.model_name}")
            except Exception as e:
                logger.error(f"Vertex AI initialization failed: {e}")
                self.model = None
        else:
            logger.warning("GCP_PROJECT_ID not set - Vertex AI not initialized")

    def chat(
        self,
        user_message: str,
        context: Dict = None,
        conversation_history: List[Dict] = None,
        max_tokens: int = 4096,
        temperature: float = 0.7,
        retry_count: int = 3
    ) -> str:
        """
        Send message to Claude via Vertex AI with comprehensive error handling

        Args:
            user_message: User's input message
            context: Project context dictionary
            conversation_history: List of previous messages
            max_tokens: Maximum tokens in response
            temperature: Response randomness (0-1)
            retry_count: Number of retries on failure

        Returns:
            Claude's response or error message
        """
        if not self.model:
            return self._format_error(
                "Vertex AI not configured",
                "Set GCP_PROJECT_ID environment variable and ensure Vertex AI is enabled"
            )

        start_time = time.time()

        # Build prompt
        try:
            full_prompt = self._build_prompt(user_message, context, conversation_history)
        except Exception as e:
            logger.error(f"Prompt building error: {e}")
            return self._format_error("Failed to build prompt", str(e))

        # Call Vertex AI with retry logic
        for attempt in range(retry_count):
            try:
                # Configure generation
                generation_config = GenerationConfig(
                    max_output_tokens=max_tokens,
                    temperature=temperature,
                )

                # Call Claude
                response = self.model.generate_content(
                    full_prompt,
                    generation_config=generation_config
                )

                # Calculate metrics
                self.last_response_time = time.time() - start_time
                self._calculate_cost(full_prompt, response.text)
                self.total_requests += 1

                logger.info(f"Request successful - Cost: ${self.last_request_cost:.4f}, Time: {self.last_response_time:.2f}s")

                return response.text

            except Exception as e:
                logger.warning(f"Attempt {attempt + 1}/{retry_count} failed: {e}")

                if attempt < retry_count - 1:
                    # Exponential backoff
                    wait_time = (2 ** attempt) * 1
                    logger.info(f"Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    # Final attempt failed
                    logger.error(f"All retry attempts failed: {e}")
                    return self._format_error(
                        "Vertex AI request failed",
                        str(e),
                        self._get_troubleshooting_steps()
                    )

        return self._format_error("Maximum retries exceeded", "Please try again later")

    def _build_prompt(
        self,
        user_message: str,
        context: Dict = None,
        conversation_history: List[Dict] = None
    ) -> str:
        """Build comprehensive prompt with system context"""
        system_prompt = self._build_system_prompt(context)

        full_prompt = f"{system_prompt}\n\n"

        # Add conversation history (last 10 messages)
        if conversation_history:
            history_to_include = conversation_history[-10:]
            for msg in history_to_include:
                role = msg['role'].upper()
                content = msg['content']
                full_prompt += f"{role}: {content}\n\n"

        full_prompt += f"USER: {user_message}\n\nASSISTANT:"

        return full_prompt

    def _build_system_prompt(self, context: Dict = None) -> str:
        """Build enhanced system prompt with project context"""
        base_prompt = """You are Claude, technical co-founder in a 90-day bootstrap mission.

MISSION CONTEXT:
- Partnership: James (vision/strategy) + Claude (technical/execution)
- Timeline: Oct 17, 2025 → Jan 15, 2026 (90 days)
- Goal: $15,000 monthly recurring revenue
- Primary Revenue Stream: HAVEN Platform (community/service hub)
- Infrastructure: GCP (Cloud Run, Firestore, Vertex AI)
- Philosophy: Ship fast, iterate constantly, delegate to AI agents

CAPABILITIES:
- Full-stack development (Python, JavaScript, React, FastAPI)
- GCP infrastructure and deployment
- Database design and optimization
- API development and integration
- UI/UX design with modern frameworks
- DevOps and CI/CD pipelines"""

        if context:
            base_prompt += "\n\nCURRENT PROJECT CONTEXT:\n"
            for key, value in context.items():
                if key not in ['created_at', 'last_updated']:
                    base_prompt += f"- {key}: {value}\n"

        base_prompt += """
COMMUNICATION STYLE:
- Be direct, technical, and action-oriented
- Provide working code examples
- Include deployment and testing steps
- Focus on pragmatic solutions
- No unnecessary explanations

When asked to build something:
1. Confirm requirements
2. Design architecture
3. Generate production-ready code
4. Provide deployment instructions
5. Suggest testing approaches
"""

        return base_prompt

    def _calculate_cost(self, prompt: str, response: str):
        """
        Calculate approximate cost based on token count
        Note: This is an estimation. Actual costs may vary.
        """
        # Rough estimation: 1 token ≈ 4 characters
        input_tokens = len(prompt) / 4
        output_tokens = len(response) / 4

        input_cost = (input_tokens / 1000) * self.PRICING['input']
        output_cost = (output_tokens / 1000) * self.PRICING['output']

        self.last_request_cost = input_cost + output_cost
        self.total_cost += self.last_request_cost

        logger.debug(f"Cost calculation - Input: {input_tokens:.0f} tokens, Output: {output_tokens:.0f} tokens")

    def _format_error(self, title: str, details: str, troubleshooting: str = None) -> str:
        """Format error message for user display"""
        error_msg = f"""❌ **{title}**

**Details:** {details}
"""

        if troubleshooting:
            error_msg += f"\n**Troubleshooting:**\n{troubleshooting}\n"

        error_msg += f"""
**Configuration:**
- Project ID: {self.project_id or 'NOT SET'}
- Region: {self.location}
- Model: {self.model_name}

**Need Help?**
Check the deployment documentation or run the diagnostic script.
"""
        return error_msg

    def _get_troubleshooting_steps(self) -> str:
        """Get troubleshooting steps for common issues"""
        return """
1. Verify GCP_PROJECT_ID environment variable is set correctly
2. Ensure Claude is enabled in Vertex AI Model Garden
3. Check service account has Vertex AI User role
4. Verify the model name is correct for your region
5. Check GCP quotas and billing
6. Review Cloud Logging for detailed error messages
"""

    def get_stats(self) -> Dict:
        """Get current usage statistics"""
        return {
            'total_requests': self.total_requests,
            'total_cost': round(self.total_cost, 4),
            'last_request_cost': round(self.last_request_cost, 4),
            'last_response_time': round(self.last_response_time, 2),
            'model': self.model_name,
            'project_id': self.project_id,
            'location': self.location
        }

    def reset_stats(self):
        """Reset usage statistics"""
        self.total_requests = 0
        self.total_cost = 0.0
        self.last_request_cost = 0.0
        logger.info("Usage statistics reset")

    def health_check(self) -> Dict:
        """Check health status of Vertex AI connection"""
        status = {
            'healthy': False,
            'project_configured': bool(self.project_id),
            'model_initialized': bool(self.model),
            'timestamp': datetime.now().isoformat()
        }

        if self.model:
            try:
                # Try a simple test request
                test_response = self.model.generate_content(
                    "Respond with just 'OK'",
                    generation_config=GenerationConfig(max_output_tokens=10)
                )
                status['healthy'] = 'OK' in test_response.text
                status['test_response'] = test_response.text
            except Exception as e:
                status['error'] = str(e)
                logger.error(f"Health check failed: {e}")

        return status
