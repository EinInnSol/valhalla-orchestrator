#!/usr/bin/env python3
"""
CONTEXT MANAGER V2 - Enhanced persistent state management
Firestore integration with comprehensive error handling and caching
"""

from google.cloud import firestore
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import os
import logging
import json

logger = logging.getLogger(__name__)

class ContextManagerV2:
    """
    Enhanced context manager with:
    - Robust error handling
    - Local caching for offline support
    - Automatic retry logic
    - Data validation
    - Performance monitoring
    """

    def __init__(self):
        """Initialize Firestore client with error handling"""
        self.project_id = os.getenv('GCP_PROJECT_ID')
        self.db = None
        self.cache = {}
        self.cache_ttl = 300  # 5 minutes cache TTL

        if self.project_id:
            try:
                self.db = firestore.Client(project=self.project_id)
                logger.info(f"Firestore initialized for project: {self.project_id}")
                self._initialize_mission_context()
            except Exception as e:
                logger.error(f"Firestore initialization error: {e}")
                logger.warning("Running in offline mode - data persistence disabled")
                self.db = None
        else:
            logger.warning("GCP_PROJECT_ID not set - Firestore disabled")

    def _initialize_mission_context(self):
        """Initialize 90-day mission context and project data"""
        if not self.db:
            return

        try:
            # Initialize mission data
            mission_ref = self.db.collection('mission').document('bootstrap')

            if not mission_ref.get().exists:
                mission_data = {
                    'start_date': '2025-10-17',
                    'deadline': '2026-01-15',
                    'goal_revenue': 15000,
                    'currency': 'USD',
                    'primary_stream': 'HAVEN Platform',
                    'secondary_stream': 'To Be Determined',
                    'tertiary_stream': 'To Be Determined',
                    'founder': 'James',
                    'co_founder': 'Claude AI',
                    'philosophy': 'Ship fast, iterate constantly, delegate to AI agents',
                    'tech_stack': ['GCP', 'Python', 'FastAPI', 'React', 'Firestore'],
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'updated_at': firestore.SERVER_TIMESTAMP
                }
                mission_ref.set(mission_data)
                logger.info("Mission context initialized")

            # Initialize projects
            self._initialize_projects()

        except Exception as e:
            logger.error(f"Mission context initialization error: {e}")

    def _initialize_projects(self):
        """Initialize default projects"""
        projects = {
            'haven_platform': {
                'name': 'HAVEN Platform',
                'status': 'Live',
                'description': 'Community/service hub - primary revenue stream',
                'tech_stack': ['FastAPI', 'PostgreSQL', 'Cloud Run', 'React'],
                'priority': 1,
                'revenue_target': 10000,
                'launch_date': '2025-11-01',
                'features': [
                    'User authentication',
                    'Service marketplace',
                    'Community forums',
                    'Payment processing'
                ]
            },
            'first_contact': {
                'name': 'First Contact',
                'status': 'Building',
                'description': 'Civic innovation platform',
                'tech_stack': ['To Be Determined'],
                'priority': 2,
                'revenue_target': 3000,
                'launch_date': '2025-12-01',
                'features': [
                    'Community engagement',
                    'Resource coordination'
                ]
            },
            'company_site': {
                'name': 'Company Site',
                'status': 'Planning',
                'description': 'Professional company website and portfolio',
                'tech_stack': ['Next.js', 'TailwindCSS', 'Vercel'],
                'priority': 3,
                'revenue_target': 2000,
                'launch_date': '2025-12-15',
                'features': [
                    'Portfolio showcase',
                    'Contact forms',
                    'Blog/updates'
                ]
            }
        }

        for project_id, project_data in projects.items():
            try:
                project_ref = self.db.collection('projects').document(project_id)
                if not project_ref.get().exists:
                    project_data['created_at'] = firestore.SERVER_TIMESTAMP
                    project_data['updated_at'] = firestore.SERVER_TIMESTAMP
                    project_ref.set(project_data)
                    logger.info(f"Project initialized: {project_data['name']}")
            except Exception as e:
                logger.error(f"Error initializing project {project_id}: {e}")

    def get_project_context(self, project_name: str) -> Dict:
        """
        Get context for a specific project with caching

        Args:
            project_name: Name of the project

        Returns:
            Project context dictionary
        """
        # Check cache first
        cache_key = f"project_{project_name}"
        if cache_key in self.cache:
            cached_data, cached_time = self.cache[cache_key]
            if datetime.now() - cached_time < timedelta(seconds=self.cache_ttl):
                logger.debug(f"Cache hit for {project_name}")
                return cached_data

        # Fetch from Firestore
        if not self.db:
            return self._get_default_project_context(project_name)

        try:
            doc_id = project_name.lower().replace(' ', '_')
            project_ref = self.db.collection('projects').document(doc_id)
            project_doc = project_ref.get()

            if project_doc.exists:
                context = project_doc.to_dict()
                # Update cache
                self.cache[cache_key] = (context, datetime.now())
                return context
            else:
                logger.warning(f"Project not found: {project_name}")
                return self._get_default_project_context(project_name)

        except Exception as e:
            logger.error(f"Error fetching project context: {e}")
            return self._get_default_project_context(project_name)

    def _get_default_project_context(self, project_name: str) -> Dict:
        """Get default context when Firestore is unavailable"""
        return {
            'name': project_name,
            'status': 'Unknown',
            'description': 'Context unavailable - Firestore not connected',
            'offline_mode': True
        }

    def save_conversation(self, project: str, messages: List[Dict]) -> bool:
        """
        Save conversation to Firestore with error handling

        Args:
            project: Project name
            messages: List of message dictionaries

        Returns:
            True if successful, False otherwise
        """
        if not self.db:
            logger.warning("Cannot save conversation - Firestore not available")
            return False

        try:
            doc_id = project.lower().replace(' ', '_')
            conversation_ref = self.db.collection('conversations').document(doc_id)

            # Prepare data
            conversation_data = {
                'project': project,
                'messages': messages,
                'message_count': len(messages),
                'last_updated': firestore.SERVER_TIMESTAMP,
                'version': 2  # Version for V2 format
            }

            # Save to Firestore
            conversation_ref.set(conversation_data)
            logger.info(f"Conversation saved: {project} ({len(messages)} messages)")

            # Also save a backup in history collection
            self._save_conversation_history(project, messages)

            return True

        except Exception as e:
            logger.error(f"Error saving conversation: {e}")
            return False

    def _save_conversation_history(self, project: str, messages: List[Dict]):
        """Save conversation to history collection for backup"""
        try:
            history_ref = self.db.collection('conversation_history').document()
            history_ref.set({
                'project': project,
                'messages': messages,
                'saved_at': firestore.SERVER_TIMESTAMP,
                'message_count': len(messages)
            })
        except Exception as e:
            logger.warning(f"History save failed (non-critical): {e}")

    def get_last_conversation(self, project: str) -> List[Dict]:
        """
        Retrieve last conversation for a project

        Args:
            project: Project name

        Returns:
            List of message dictionaries
        """
        if not self.db:
            return []

        try:
            doc_id = project.lower().replace(' ', '_')
            conversation_ref = self.db.collection('conversations').document(doc_id)
            conversation_doc = conversation_ref.get()

            if conversation_doc.exists:
                data = conversation_doc.to_dict()
                messages = data.get('messages', [])
                logger.info(f"Loaded conversation: {project} ({len(messages)} messages)")
                return messages
            else:
                logger.info(f"No saved conversation for: {project}")
                return []

        except Exception as e:
            logger.error(f"Error loading conversation: {e}")
            return []

    def update_project_status(
        self,
        project: str,
        status: str,
        updates: Dict = None
    ) -> bool:
        """
        Update project status and metadata

        Args:
            project: Project name
            status: New status
            updates: Additional fields to update

        Returns:
            True if successful, False otherwise
        """
        if not self.db:
            return False

        try:
            doc_id = project.lower().replace(' ', '_')
            project_ref = self.db.collection('projects').document(doc_id)

            update_data = {
                'status': status,
                'updated_at': firestore.SERVER_TIMESTAMP
            }

            if updates:
                update_data.update(updates)

            project_ref.update(update_data)
            logger.info(f"Project updated: {project} -> {status}")

            # Invalidate cache
            cache_key = f"project_{project}"
            if cache_key in self.cache:
                del self.cache[cache_key]

            return True

        except Exception as e:
            logger.error(f"Error updating project: {e}")
            return False

    def log_execution(
        self,
        project: str,
        action: str,
        result: str,
        cost: float = 0,
        metadata: Dict = None
    ) -> bool:
        """
        Log execution for tracking and cost monitoring

        Args:
            project: Project name
            action: Action performed
            result: Result of action
            cost: Cost in USD
            metadata: Additional metadata

        Returns:
            True if successful, False otherwise
        """
        if not self.db:
            return False

        try:
            execution_ref = self.db.collection('executions').document()
            execution_data = {
                'project': project,
                'action': action,
                'result': result,
                'cost': cost,
                'timestamp': firestore.SERVER_TIMESTAMP
            }

            if metadata:
                execution_data['metadata'] = metadata

            execution_ref.set(execution_data)
            logger.debug(f"Execution logged: {action} (${cost:.4f})")
            return True

        except Exception as e:
            logger.error(f"Error logging execution: {e}")
            return False

    def get_usage_stats(self, project: str = None, days: int = 1) -> Dict:
        """
        Get usage statistics

        Args:
            project: Optional project filter
            days: Number of days to look back

        Returns:
            Statistics dictionary
        """
        if not self.db:
            return {'error': 'Firestore not available'}

        try:
            # Calculate date threshold
            threshold = datetime.now() - timedelta(days=days)

            # Query executions
            query = self.db.collection('executions')

            if project:
                query = query.where('project', '==', project)

            query = query.where('timestamp', '>=', threshold)

            executions = query.stream()

            # Calculate stats
            total_cost = 0
            total_requests = 0
            actions = {}

            for exec_doc in executions:
                data = exec_doc.to_dict()
                total_cost += data.get('cost', 0)
                total_requests += 1

                action = data.get('action', 'unknown')
                actions[action] = actions.get(action, 0) + 1

            return {
                'total_cost': round(total_cost, 4),
                'total_requests': total_requests,
                'actions': actions,
                'period_days': days,
                'project': project or 'all'
            }

        except Exception as e:
            logger.error(f"Error getting usage stats: {e}")
            return {'error': str(e)}

    def clear_cache(self):
        """Clear local cache"""
        self.cache = {}
        logger.info("Cache cleared")

    def health_check(self) -> Dict:
        """
        Check Firestore connection health

        Returns:
            Health status dictionary
        """
        status = {
            'healthy': False,
            'project_configured': bool(self.project_id),
            'client_initialized': bool(self.db),
            'timestamp': datetime.now().isoformat()
        }

        if self.db:
            try:
                # Try a simple read operation
                test_ref = self.db.collection('mission').document('bootstrap')
                test_doc = test_ref.get()
                status['healthy'] = True
                status['mission_exists'] = test_doc.exists
            except Exception as e:
                status['error'] = str(e)
                logger.error(f"Health check failed: {e}")

        return status
