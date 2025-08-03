# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GameMaster's Companion (GMC)** is a privacy-focused, self-hosted digital assistant for tabletop RPG Game Masters and players. It provides AI-enhanced content management, real-time collaboration, and intelligent automation for D&D 5e and similar RPG systems.

### Architecture Overview
- **Frontend**: React with TypeScript, designed for multi-device collaboration
- **Backend**: FastAPI (Python) with PostgreSQL, Redis, and Elasticsearch  
- **AI/ML**: Local LLM deployment (vllm) and audio processing (diart)
- **Infrastructure**: Kubernetes-native deployment optimized for self-hosting

### Core Features
- Character Management with relationship tracking
- World Building with hierarchical location system
- AI-powered content generation and session summarization
- Real-time audio processing and keyword detection
- Multi-device collaboration with role-based access
- Intelligent fuzzy search for fantasy terminology

## Quick Start

### Prerequisites
- Docker Desktop (running)
- Kind v0.20+
- kubectl v1.28+
- Helm v3.12+

### Development Environment Setup
```bash
# Make scripts executable (Linux/Mac)
chmod +x infrastructure/scripts/*.sh

# Create and configure Kind cluster with all services
./infrastructure/scripts/setup-kind-cluster.sh
```

### Essential Commands
```bash
# Check status of all services
./infrastructure/scripts/dev-workflow.sh status

# View service logs
./infrastructure/scripts/dev-workflow.sh logs <service>

# Access services locally
./infrastructure/scripts/dev-workflow.sh port-forward all
```

### Service Endpoints
- **Frontend**: http://localhost:3000
- **API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Database**: localhost:5432 (postgres/changeme)

## Component-Specific Guidance

For detailed guidance on working with specific components:

- **Infrastructure**: See [infrastructure/CLAUDE.md](infrastructure/CLAUDE.md) for Kubernetes, Helm, and deployment guidance
- **Backend**: See [backend/CLAUDE.md](backend/CLAUDE.md) for FastAPI, database, and AI service development
- **Frontend**: See [frontend/CLAUDE.md](frontend/CLAUDE.md) for React, UI components, and real-time features

## Current Development Status

- ✅ Complete Kubernetes infrastructure with Kind development environment
- ✅ Helm charts for all services with comprehensive configuration
- ✅ Development workflow automation scripts
- 🚧 Core API implementation (planned)
- 🚧 Frontend development (planned)
- 📋 AI integration implementation (planned)

## Project Structure

```
DnD/
├── CLAUDE.md               # This file - project overview
├── README.md               # Quick start and project overview
├── PRD.md                  # Product Requirements Document
├── ROADMAP.md              # Implementation roadmap
├── USERSTORIES.md          # User requirements by persona
├── infrastructure/         # Kubernetes deployment and infrastructure
│   ├── CLAUDE.md          # Infrastructure-specific guidance
│   ├── README.md          # Infrastructure setup guide
│   ├── helm/gmc-dev/      # Helm chart for deployment
│   └── scripts/           # Automation scripts
├── backend/                # FastAPI backend services
│   └── CLAUDE.md          # Backend development guidance
└── frontend/               # React frontend application
    └── CLAUDE.md          # Frontend development guidance
```