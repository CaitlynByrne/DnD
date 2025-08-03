# Backend - CLAUDE.md

This file provides backend-specific guidance for GameMaster's Companion API development using FastAPI and Python.

## Overview

The GMC backend is a FastAPI-based microservice architecture providing RESTful APIs, WebSocket real-time communication, and integration with AI/ML services. It emphasizes privacy-first design with local processing and comprehensive data management for RPG campaigns.

## Technology Stack

### Core Technologies
- **FastAPI** with Python 3.11+ for REST and WebSocket APIs
- **PostgreSQL** with extensions for similarity search, vector storage, and graph storage
- **Redis** for caching and real-time features
- **Elasticsearch** for fuzzy search capabilities
- **SQLAlchemy** for database ORM
- **Alembic** for database migrations
- **Pydantic** for data validation and serialization

### Key Architecture Components
- **Authentication**: OAuth2/JWT with role-based access control
- **Database**: Flexible schema supporting various RPG systems
- **Search**: Phonetic and fuzzy matching for fantasy terminology
- **AI Integration**: Local LLM deployment and audio processing
- **Real-time**: WebSocket communication for live collaboration

## Development Environment

### Backend Service Access
```bash
# Start backend development environment
./infrastructure/scripts/dev-workflow.sh port-forward api

# Access API
# http://localhost:8000

# Access API documentation
# http://localhost:8000/docs
```

### Development Commands
```bash
# View backend logs
./infrastructure/scripts/dev-workflow.sh logs api

# Follow backend logs in real-time
./infrastructure/scripts/dev-workflow.sh logs api follow

# Restart backend service
./infrastructure/scripts/dev-workflow.sh restart api

# Run database migrations
./infrastructure/scripts/dev-workflow.sh migrate

# Seed test data
./infrastructure/scripts/dev-workflow.sh seed
```

## Database Architecture

### Core Data Models

**Characters (PCs and NPCs):**
- Flexible schema supporting various RPG systems
- Voice characteristics and roleplay notes
- Relationship mapping and character evolution tracking
- Achievement and story arc progression
- Integration with external character sources (D&D Beyond)

**Locations and World Building:**
- Hierarchical data structure with spatial relationships
- Multi-level location hierarchy (world → region → city → building → room)
- Environmental conditions and atmosphere data
- Population, demographic, and economic information

**Sessions and Campaign Data:**
- Time-series data with rich metadata and full-text search
- Audio file storage with metadata linking to transcripts
- Real-time transcription and speaker identification
- Plot point extraction and categorization

**Search and Discovery:**
- Full-text search with PostgreSQL extensions
- Elasticsearch integration for advanced fuzzy matching
- Phonetic matching algorithms (Soundex, Metaphone)
- Context-aware search suggestions

### Database Operations
```bash
# Direct PostgreSQL access
kubectl exec -it deployment/gmc-dev-postgresql -n gmc-dev -- psql -U postgres -d gamemaster_companion

# Database connection details
# Host: localhost:5432
# Username: postgres
# Password: changeme
# Database: gamemaster_companion
```

### Database Migrations
```bash
# Run migrations
./infrastructure/scripts/dev-workflow.sh migrate

# Create new migration (when backend code exists)
# alembic revision --autogenerate -m "Description of changes"

# Apply specific migration
# alembic upgrade head
```

## API Architecture

### Core API Endpoints

**Authentication & Authorization:**
- JWT-based authentication with refresh tokens
- Role-based access control (GM, Player, Observer)
- Multi-factor authentication support
- Session management across devices

**Character Management:**
- CRUD operations for player characters and NPCs
- Character relationship tracking
- Voice notes and roleplay guidance
- Character import from external sources
- Character progression and achievement tracking

**World & Location Management:**
- Hierarchical location CRUD operations
- Spatial relationship management
- Environmental condition tracking
- Integration with battle map systems

**Session Management:**
- Real-time session creation and management
- Audio processing and transcription integration
- Live keyword detection and reference lookup
- Session note generation and summarization

**Search & Discovery:**
- Fuzzy search across all campaign data
- Phonetic matching for fantasy names
- Cross-reference search capabilities
- AI-enhanced search suggestions

### WebSocket Endpoints

**Real-time Collaboration:**
- Session state synchronization
- Multi-device collaboration
- Live audio processing results
- Real-time character sheet updates
- Push notifications for session events

### API Documentation
```bash
# Interactive API documentation
http://localhost:8000/docs

# OpenAPI schema
http://localhost:8000/openapi.json
```

## AI/ML Integration

### Local LLM Services
```bash
# Access vLLM API
http://localhost:8001

# Audio processor service
http://localhost:8002
```

### AI Integration Points

**Content Generation:**
- AI-powered NPC generation with campaign consistency
- Location and encounter generation
- Custom random table creation
- Seed-based generation for reproducibility

**Session Enhancement:**
- Real-time transcription with speaker diarization
- Automatic session summarization
- Plot point extraction and categorization
- Action item generation for future sessions

**Audio Processing:**
- Integration with PyAnnote.audio/diart for speaker diarization
- Keyword detection for rules, spells, monsters, conditions
- Real-time transcription with speaker identification
- Automatic annotation of in-character vs out-of-character speech

## Security Architecture

### Authentication & Authorization
- JWT tokens with configurable expiration
- Role-based permissions (GM, Player, Observer)
- Multi-device session management
- Secure password hashing and storage

### Data Security
- Encryption at rest for sensitive campaign data
- TLS encryption for all API communication
- Audit logging for all data modifications
- Local processing ensures data never leaves the self-hosted environment

### Privacy-First Design
- No external API dependencies for core functionality
- Local AI processing maintains data sovereignty
- Configurable data retention policies
- GDPR-compliant data management

## Performance Optimization

### Database Performance
- Proper indexing strategies for search operations
- Connection pooling and query optimization
- Background task processing for AI operations
- Caching strategies with Redis

### API Performance
- Response time targets: < 200ms for database queries, < 2s for AI generation
- Async/await patterns for I/O operations
- Background task queues for long-running operations
- Rate limiting and request throttling

### Real-time Performance
- WebSocket connection management
- Efficient message broadcasting
- Audio processing with < 5s delay
- Sub-second fuzzy search results

## Testing Strategy

### Backend Testing
```bash
# Run backend tests (when implemented)
# pytest (from backend directory)

# Test with real database
# pytest --integration

# Load testing
# locust --config locustfile.py
```

### Testing Focus Areas
- API endpoint functionality and validation
- Database operations and migrations
- Authentication and authorization
- Real-time WebSocket communication
- AI service integration
- Search functionality accuracy
- Performance under load

## Development Guidelines

### Code Organization
- Follow FastAPI best practices
- Pydantic models for request/response validation
- SQLAlchemy models for database operations
- Dependency injection for service layer
- Proper error handling and logging

### Environment Configuration
```bash
# Key environment variables (managed via Helm)
DATABASE_URL=postgresql://postgres:changeme@postgresql:5432/gamemaster_companion
REDIS_URL=redis://redis:6379/0
ELASTICSEARCH_URL=http://elasticsearch:9200
VLLM_API_URL=http://vllm-service:8000
AI_ENABLED=true
DEBUG=true
```

### Database Best Practices
- Use Alembic for all schema changes
- Implement proper foreign key relationships
- Use database constraints for data integrity
- Design for horizontal scaling
- Implement soft deletes for audit trails

### API Development Guidelines
- RESTful API design principles
- Comprehensive input validation
- Proper HTTP status codes
- Consistent error response format
- API versioning strategy
- Rate limiting implementation

## Debugging and Troubleshooting

### Backend Debugging
```bash
# Check backend service status
./infrastructure/scripts/dev-workflow.sh logs api

# Access backend container for debugging
kubectl exec -it deployment/gmc-dev-api -n gmc-dev -- /bin/bash

# Check API connectivity
curl http://localhost:8000/health

# Test database connection
curl http://localhost:8000/health/db
```

### Common Issues

**Database Connection Issues:**
```bash
# Check PostgreSQL service
kubectl get pods -n gmc-dev -l app.kubernetes.io/name=postgresql

# Test database connectivity
kubectl exec -it deployment/gmc-dev-postgresql -n gmc-dev -- psql -U postgres -c "SELECT version();"
```

**AI Service Integration:**
```bash
# Check vLLM service status
curl http://localhost:8001/health

# Check audio processor status
curl http://localhost:8002/health

# Monitor AI service resources
kubectl top pods -n gmc-dev -l app.kubernetes.io/component=vllm
```

**Performance Issues:**
```bash
# Monitor API resource usage
kubectl top pods -n gmc-dev -l app.kubernetes.io/component=api

# Check Redis connectivity
kubectl exec -it deployment/gmc-dev-redis-master -n gmc-dev -- redis-cli ping

# Monitor Elasticsearch
curl http://localhost:9200/_cluster/health
```

## Integration Points

### External Service Integration
- **D&D Beyond API**: Character import and synchronization
- **Discord Webhooks**: Automated session summary posting
- **VTT Integration**: Battle map and token synchronization

### Internal Service Communication
- **Frontend API**: RESTful endpoints and WebSocket communication
- **AI Services**: Local LLM and audio processing integration
- **Search Services**: Elasticsearch for advanced search capabilities
- **Cache Layer**: Redis for performance optimization

## Data Management

### Backup and Recovery
```bash
# Database backup (development)
kubectl exec deployment/gmc-dev-postgresql -n gmc-dev -- pg_dump -U postgres gamemaster_companion > backup.sql

# Database restore (development)
kubectl exec -i deployment/gmc-dev-postgresql -n gmc-dev -- psql -U postgres gamemaster_companion < backup.sql
```

### Data Migration and Seeding
```bash
# Seed development data
./infrastructure/scripts/dev-workflow.sh seed

# Custom data migration scripts (when implemented)
# python scripts/migrate_legacy_data.py
```

## Future Considerations

### Scalability Planning
- Horizontal scaling strategies
- Database sharding considerations
- Microservice decomposition
- Load balancing implementation

### Advanced Features
- GraphQL API implementation
- Advanced AI model integration
- Multi-language support
- Plugin architecture for custom features