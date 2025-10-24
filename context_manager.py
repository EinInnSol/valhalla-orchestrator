#!/usr/bin/env python3
"""
CONTEXT MANAGER - Persistent state in Firestore
Remembers everything so you never start over
"""

from google.cloud import firestore
from datetime import datetime
from typing import Dict, List
import os

class ContextManager:
    def __init__(self):
        self.project_id = os.getenv('GCP_PROJECT_ID')
        
        if self.project_id:
            try:
                self.db = firestore.Client(project=self.project_id)
            except Exception as e:
                print(f"Firestore init error: {e}")
                self.db = None
        else:
            self.db = None
        
        # Initialize mission context if needed
        if self.db:
            self._initialize_mission_context()
    
    def _initialize_mission_context(self):
        """
        Initialize 90-day mission context in Firestore
        """
        mission_ref = self.db.collection('mission').document('bootstrap')
        
        # Check if already initialized
        if not mission_ref.get().exists:
            mission_data = {
                'start_date': '2025-10-17',
                'deadline': '2026-01-15',
                'goal_revenue': 15000,
                'primary_stream': 'HAVEN Platform',
                'secondary_stream': 'TBD',
                'tertiary_stream': 'TBD',
                'founder': 'James',
                'co_founder': 'Claude',
                'philosophy': 'Ship fast, iterate, delegate to agents',
                'created_at': firestore.SERVER_TIMESTAMP
            }
            mission_ref.set(mission_data)
        
        # Initialize project contexts
        projects = {
            'HAVEN Platform': {
                'status': 'Live',
                'description': 'Community/service hub - primary revenue',
                'tech_stack': ['FastAPI', 'PostgreSQL', 'Cloud Run'],
                'priority': 1
            },
            'First Contact': {
                'status': 'Building',
                'description': 'Next civic innovation platform',
                'tech_stack': ['TBD'],
                'priority': 2
            },
            'Company Site': {
                'status': 'Planning',
                'description': 'Professional company website',
                'tech_stack': ['Next.js', 'TailwindCSS'],
                'priority': 3
            }
        }
        
        for project_name, project_data in projects.items():
            project_ref = self.db.collection('projects').document(project_name.lower().replace(' ', '_'))
            if not project_ref.get().exists:
                project_data['created_at'] = firestore.SERVER_TIMESTAMP
                project_ref.set(project_data)
    
    def get_project_context(self, project_name: str) -> Dict:
        """
        Get context for a specific project
        """
        if not self.db:
            return {}
        
        doc_id = project_name.lower().replace(' ', '_')
        project_ref = self.db.collection('projects').document(doc_id)
        project_doc = project_ref.get()
        
        if project_doc.exists:
            return project_doc.to_dict()
        return {}
    
    def save_conversation(self, project: str, messages: List[Dict]):
        """
        Save conversation to Firestore for persistence
        """
        if not self.db:
            return
        
        doc_id = project.lower().replace(' ', '_')
        conversation_ref = self.db.collection('conversations').document(doc_id)
        
        conversation_ref.set({
            'project': project,
            'messages': messages,
            'last_updated': firestore.SERVER_TIMESTAMP,
            'message_count': len(messages)
        })
    
    def get_last_conversation(self, project: str) -> List[Dict]:
        """
        Retrieve last conversation for a project
        """
        if not self.db:
            return []
        
        doc_id = project.lower().replace(' ', '_')
        conversation_ref = self.db.collection('conversations').document(doc_id)
        conversation_doc = conversation_ref.get()
        
        if conversation_doc.exists:
            return conversation_doc.to_dict().get('messages', [])
        return []
    
    def update_project_status(self, project: str, status: str, updates: Dict = None):
        """
        Update project status and metadata
        """
        if not self.db:
            return
        
        doc_id = project.lower().replace(' ', '_')
        project_ref = self.db.collection('projects').document(doc_id)
        
        update_data = {
            'status': status,
            'last_updated': firestore.SERVER_TIMESTAMP
        }
        
        if updates:
            update_data.update(updates)
        
        project_ref.update(update_data)
    
    def log_execution(self, project: str, action: str, result: str, cost: float = 0):
        """
        Log execution for tracking and cost monitoring
        """
        if not self.db:
            return
        
        execution_ref = self.db.collection('executions').document()
        execution_ref.set({
            'project': project,
            'action': action,
            'result': result,
            'cost': cost,
            'timestamp': firestore.SERVER_TIMESTAMP
        })