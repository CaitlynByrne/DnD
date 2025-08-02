# GameMaster's Companion (GMC)

A privacy-focused, self-hosted digital assistant that empowers Game Masters to run more engaging and seamless tabletop RPG sessions through intelligent automation, real-time collaboration, and AI-enhanced content management.

## Vision

Eliminate the administrative burden on Game Masters while enhancing player engagement through technology, without compromising the human storytelling element that makes tabletop RPGs special.

## Key Features

- **Character Management** - Comprehensive database for PCs and NPCs with relationship tracking
- **World Building** - Hierarchical location system with rich environmental details
- **Random Generation** - AI-powered content creation for on-the-fly storytelling
- **Live Session Assistant** - Real-time audio processing and keyword detection
- **Smart Note-Taking** - AI-enhanced session summarization and automatic updates
- **Plot Management** - Visual tools for tracking storylines and character arcs
- **Intelligent Search** - Fuzzy search designed for fantasy names and terminology
- **Multi-Device Collaboration** - Real-time synchronization with role-based access

## Privacy First

- **Complete Data Sovereignty** through self-hosting
- **No External Dependencies** - all processing happens locally
- **Open Source** - full transparency and community control
- **Local AI Processing** - your campaign data never leaves your server

## Architecture

- **Frontend:** React with TypeScript and real-time WebSocket integration
- **Backend:** FastAPI (Python) with PostgreSQL and Redis
- **AI/ML:** Local LLM deployment via vllm, diart for speech processing
- **Infrastructure:** Kubernetes-native deployment with comprehensive monitoring

## Target Users

- **Primary:** Game Masters running D&D 5e and similar tabletop RPGs
- **Secondary:** Players seeking enhanced character tracking and session engagement
- **Tertiary:** Content creators and homebrew developers

## Project Status

**Current Phase:** Definition and Planning

This project is currently in the early definition phase. We are:
- Finalizing requirements and user stories
- Designing system architecture
- Planning development phases
- Building the technical foundation

## Documentation

- [**Product Requirements Document**](PRD.md) - Comprehensive feature specifications and technical requirements
- [**Development Roadmap**](ROADMAP.md) - Implementation strategy and project timeline
- [**User Stories**](USERSTORIES.md) - Detailed user requirements organized by persona and feature

## Development Phases

1. **Foundation** (Months 1-3) - Core infrastructure and basic functionality
2. **Live Session Features** (Months 4-6) - Real-time collaboration and audio processing
3. **AI Enhancement** (Months 7-9) - Advanced AI features and content generation
4. **Advanced Features** (Months 10-12) - Polish and community features
