# Backend Technical PRD - GameMaster's Companion

## Overview

The backend provides a robust, scalable API layer that handles data management, real-time communication, AI integration, and audio processing for the GameMaster's Companion platform.

## Technical Stack

### Core Framework
- **Primary:** FastAPI (Python 3.11+) for high-performance async APIs
- **Alternative:** Node.js with Express/Fastify for JavaScript consistency
- **Database ORM:** SQLAlchemy with Alembic for database migrations
- **Async Runtime:** asyncio with uvloop for optimal performance

### Database Layer
- **Primary Database:** PostgreSQL 15+ for relational data with JSONB support
  - **Vector Extension:** pgvector for embedding storage and similarity search
  - **Graph Extension:** Apache AGE for relationship queries and graph analytics
  - **Fuzzy Search Extensions:** 
    - pg_trgm for trigram-based fuzzy matching
    - fuzzystrmatch for phonetic matching (Soundex, Metaphone, Levenshtein)
    - pg_similarity for advanced string similarity algorithms
- **Caching Layer:** Redis 7+ for session management and real-time features
- **Search Engine:** Elasticsearch 8+ for fuzzy search and full-text indexing
- **File Storage:** MinIO (S3-compatible) for media and document storage

### AI and ML Integration
- **Local LLM:** vllm for self-hosted language model inference
- **Speech Processing & Speaker Diarization:** Diart for real-time speech processing and speaker diarization
- **Text Processing:** spaCy for NLP tasks and entity extraction
- **Content Generation:** Campaign-appropriate NPC, location, and encounter generation
- **Session Summarization:** Intelligent parsing of transcripts with plot point extraction

### Real-time Communication
- **WebSocket Server:** FastAPI WebSocket support with Redis pub/sub
- **Message Queue:** Redis Streams for reliable message delivery
- **Background Tasks:** Celery with Redis broker for async processing

## Architecture Patterns

### Project Structure
```
backend/
├── app/
│   ├── api/              # API route definitions
│   │   ├── v1/          # Version 1 API endpoints
│   │   └── websocket/   # WebSocket handlers
│   ├── core/            # Core application logic
│   │   ├── config.py    # Configuration management
│   │   ├── security.py  # Authentication and authorization
│   │   └── database.py  # Database configuration
│   ├── models/          # SQLAlchemy models
│   ├── schemas/         # Pydantic schemas for validation
│   ├── services/        # Business logic layer
│   ├── repositories/    # Data access layer
│   ├── workers/         # Background task workers
│   └── utils/           # Utility functions
├── migrations/          # Database migrations
├── tests/              # Test suite
└── docker/             # Docker configuration
```

### Layered Architecture
1. **API Layer:** FastAPI routes with request/response validation
2. **Service Layer:** Business logic and orchestration
3. **Repository Layer:** Data access abstraction
4. **Model Layer:** Database entities and relationships
5. **Infrastructure Layer:** External service integrations

### Design Patterns
- **Repository Pattern:** Abstract data access for testability
- **Service Layer Pattern:** Encapsulate business logic
- **Dependency Injection:** FastAPI's built-in DI for clean testing
- **Observer Pattern:** Event-driven architecture for real-time updates

## Core Service Implementation

### 1. Character Management Service

#### Data Models
```python
class Character(Base):
    id: UUID = Field(primary_key=True)
    campaign_id: UUID = Field(foreign_key="campaigns.id")
    name: str = Field(max_length=255)
    character_type: CharacterType = Field(default=CharacterType.NPC)
    stats: dict = Field(default_factory=dict)  # JSONB field
    notes: dict = Field(default_factory=dict)  # JSONB field
    voice_notes: str = Field(nullable=True)
    relationships: List[Relationship] = Relationship(back_populates="character")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

#### API Endpoints
- `GET /api/v1/campaigns/{campaign_id}/characters` - List characters with filtering
- `POST /api/v1/campaigns/{campaign_id}/characters` - Create new character
- `GET /api/v1/characters/{character_id}` - Get character details
- `PUT /api/v1/characters/{character_id}` - Update character
- `DELETE /api/v1/characters/{character_id}` - Delete character
- `POST /api/v1/characters/{character_id}/relationships` - Manage relationships
- `POST /api/v1/characters/import/dndbeyond` - Import from D&D Beyond
- `GET /api/v1/characters/{character_id}/achievements` - Get character achievements
- `GET /api/v1/characters/{character_id}/voice-notes` - Get voice acting notes

#### Business Logic
- **Validation:** Ensure character data integrity and campaign membership
- **Search Integration:** Automatic indexing in Elasticsearch with phonetic search
- **Change Tracking:** Audit log for character modifications
- **Permission Checks:** Role-based access control for character visibility
- **D&D Beyond Integration:** Character import and synchronization
- **Relationship Tracking:** Automatic relationship updates from session transcripts

### 2. Location Management Service

#### Data Models
```python
class Location(Base):
    id: UUID = Field(primary_key=True)
    campaign_id: UUID = Field(foreign_key="campaigns.id")
    parent_id: UUID = Field(foreign_key="locations.id", nullable=True)
    name: str = Field(max_length=255)
    location_type: LocationType
    description: str = Field(nullable=True)
    metadata: dict = Field(default_factory=dict)  # JSONB field
    coordinates: dict = Field(nullable=True)  # Geographic data
    children: List["Location"] = Relationship(back_populates="parent")
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

#### API Endpoints
- `GET /api/v1/campaigns/{campaign_id}/locations` - Hierarchical location list
- `POST /api/v1/campaigns/{campaign_id}/locations` - Create location
- `GET /api/v1/locations/{location_id}` - Get location with hierarchy context
- `PUT /api/v1/locations/{location_id}` - Update location
- `POST /api/v1/locations/{location_id}/move` - Move location in hierarchy

#### Hierarchical Queries
- **Nested Set Model:** Efficient hierarchy queries with left/right indices
- **Path Materialization:** Store full path for quick ancestor queries
- **Lazy Loading:** Load child locations on demand

### 3. Session Management Service

#### Real-time Session Handling
```python
class SessionManager:
    def __init__(self, redis_client: Redis):
        self.redis = redis_client
        self.active_sessions: Dict[UUID, Session] = {}
    
    async def create_session(self, campaign_id: UUID, gm_id: UUID) -> Session:
        """Create new game session with WebSocket support"""
    
    async def join_session(self, session_id: UUID, user_id: UUID) -> bool:
        """Add user to active session"""
    
    async def broadcast_update(self, session_id: UUID, message: dict):
        """Send update to all session participants"""
```

#### WebSocket Handlers
- **Connection Management:** Handle user connections and disconnections
- **Message Routing:** Route messages based on user roles and session state
- **State Synchronization:** Keep session state consistent across clients
- **Presence Management:** Track active users and their status

### 4. Audio Processing Service

#### Speech-to-Text Pipeline with Speaker Diarization
```python
class AudioProcessor:
    def __init__(self, diart_config: dict = None):
        self.diart_pipeline = create_diart_pipeline(config=diart_config)
        self.speech_processor = DiartSpeechProcessor()
    
    async def process_audio_stream(self, audio_stream) -> StreamingTranscript:
        """Process real-time audio stream with speaker identification and transcription"""
    
    async def process_audio_chunk(self, audio_data: bytes) -> TranscriptChunk:
        """Process audio chunk with speaker diarization and speech recognition"""
    
    async def merge_transcript_chunks(self, chunks: List[TranscriptChunk]) -> Transcript:
        """Combine chunks into coherent transcript with speaker timeline"""
```

#### Keyword Detection
- **Rule-based Matching:** Regex patterns for D&D terms (spells, monsters, conditions, items)
- **Fuzzy Matching:** Levenshtein distance for similar-sounding terms
- **Phonetic Matching:** Soundex/Metaphone for pronunciation variations
- **Context Awareness:** Use sentence context to improve accuracy
- **Real-time Processing:** Stream processing for immediate keyword alerts and reference lookup

### 5. AI Integration Service

#### Content Generation
```python
class AIContentGenerator:
    def __init__(self, ollama_client: OllamaClient):
        self.llm = ollama_client
        self.prompt_templates = PromptTemplateManager()
    
    async def generate_npc(self, context: dict) -> NPCData:
        """Generate NPC with campaign-appropriate characteristics"""
    
    async def summarize_session(self, transcript: str) -> SessionSummary:
        """Create structured summary from session transcript"""
    
    async def suggest_plot_hooks(self, campaign_state: dict) -> List[PlotHook]:
        """Generate plot suggestions based on current campaign state"""
```

#### Session Summarization
- **Entity Extraction:** Identify characters, locations, and items mentioned
- **Action Classification:** Categorize events (combat, roleplay, exploration)
- **Relationship Updates:** Track character relationship changes automatically
- **Plot Point Identification:** Detect important story developments
- **Discord Integration:** Automated posting of session summaries to Discord servers
- **Achievement Tracking:** Identify character milestones and progression
- **Database Updates:** Automatic updating of character and location databases

### 6. Search Service

#### Fuzzy Search Implementation
```python
class FuzzySearchService:
    def __init__(self, elasticsearch_client: Elasticsearch):
        self.es = elasticsearch_client
        self.phonetic_encoder = DoubleMetaphone()
    
    async def search(self, query: str, filters: dict = None) -> SearchResults:
        """Multi-modal search with fuzzy matching and phonetic similarity"""
    
    def build_query(self, query: str) -> dict:
        """Construct Elasticsearch query with fuzzy and phonetic matching"""
```

#### Search Index Management
- **Multi-field Indexing:** Text, phonetic, and keyword fields
- **Real-time Updates:** Automatic re-indexing on data changes
- **Custom Analyzers:** Fantasy-name-aware text processing
- **Faceted Search:** Category-based filtering and aggregations

### 7. Plot Management Service

#### Plot Thread Tracking
```python
class PlotService:
    def __init__(self, db_session: Session):
        self.db = db_session
        self.plot_repository = PlotRepository(db_session)
    
    async def create_plot_thread(self, campaign_id: UUID, plot_data: dict) -> PlotThread:
        """Create new plot thread with dependencies and milestones"""
    
    async def track_plot_progress(self, session_id: UUID, plot_updates: List[dict]):
        """Update plot progress based on session events"""
    
    async def generate_plot_reminders(self, campaign_id: UUID) -> List[PlotReminder]:
        """Generate reminders for unresolved plot hooks"""
```

#### API Endpoints
- `GET /api/v1/campaigns/{campaign_id}/plots` - List all plot threads
- `POST /api/v1/campaigns/{campaign_id}/plots` - Create new plot thread
- `PUT /api/v1/plots/{plot_id}/progress` - Update plot progress
- `GET /api/v1/plots/{plot_id}/status` - Get plot status/progress
- `GET /api/v1/plots/{plot_id}/dependencies` - Get plot dependencies
- `POST /api/v1/plots/{plot_id}/foreshadowing` - Add foreshadowing elements

### 8. Discord Integration Service

#### Discord Bot Integration
```python
class DiscordIntegrationService:
    def __init__(self, discord_client: DiscordClient):
        self.discord = discord_client
        self.webhook_manager = WebhookManager()
    
    async def post_session_summary(self, session_id: UUID, discord_config: dict):
        """Post formatted session summary to Discord channel"""
    
    async def setup_webhook(self, guild_id: str, channel_id: str) -> str:
        """Configure Discord webhook for automated posting"""
```

#### API Endpoints
- `POST /api/v1/discord/webhooks` - Configure Discord webhook
- `POST /api/v1/sessions/{session_id}/discord/post` - Post summary to Discord
- `GET /api/v1/discord/guilds` - List available Discord servers

## Data Architecture

### Database Schema Design

#### Core Entities
- **Campaigns:** Top-level container for all game data
- **Users:** Player and GM accounts with role-based permissions
- **Characters:** Both PCs and NPCs with flexible attribute storage and voice notes
- **Locations:** Hierarchical location system with spatial data and VTT integration
- **Sessions:** Game session records with transcripts, speaker diarization, and metadata
- **Events:** Audit log for all data modifications
- **Plot Threads:** Story arc tracking with dependencies and progress indicators
- **Relationships:** Character relationship mapping with evolution tracking

#### Relationship Patterns
- **Many-to-Many:** User-Campaign relationships with roles
- **Hierarchical:** Location parent-child relationships
- **Temporal:** Session-based event tracking with timestamps
- **Flexible:** JSONB fields for game-system-specific data

#### Performance Optimizations
- **Indexing Strategy:** Composite indices for common query patterns
- **Partitioning:** Session data partitioned by campaign and date
- **Materialized Views:** Pre-computed aggregations for reporting
- **Connection Pooling:** Efficient database connection management

### Caching Strategy

#### Redis Usage Patterns
- **Session Storage:** Active session state and WebSocket connections
- **Query Caching:** Frequently accessed data with TTL
- **Rate Limiting:** API rate limiting with sliding windows
- **Pub/Sub:** Real-time event distribution

#### Cache Invalidation
- **Event-Driven:** Invalidate caches on data modifications
- **TTL-Based:** Time-based expiration for non-critical data
- **Manual Purging:** Admin tools for cache management
- **Warm-up Strategies:** Pre-load caches for better performance

## API Design

### RESTful API Principles
- **Resource-Based URLs:** Clear, hierarchical resource identification
- **HTTP Methods:** Proper use of GET, POST, PUT, DELETE, PATCH
- **Status Codes:** Meaningful HTTP status codes for all responses
- **Content Negotiation:** JSON API with optional formats

### API Versioning
- **URL Versioning:** `/api/v1/` prefix for version identification
- **Backward Compatibility:** Maintain support for previous versions
- **Deprecation Strategy:** Clear timeline for version sunset
- **Migration Tools:** Automated tools for version upgrades

### Request/Response Patterns
```python
# Pydantic schemas for validation
class CharacterCreateSchema(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    character_type: CharacterType
    stats: dict = Field(default_factory=dict)
    notes: Optional[str] = None

class CharacterResponseSchema(BaseModel):
    id: UUID
    name: str
    character_type: CharacterType
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
```

### Error Handling
- **Structured Errors:** Consistent error response format
- **Error Codes:** Application-specific error codes
- **Validation Errors:** Detailed field-level validation messages
- **Logging Integration:** Comprehensive error logging

## Security Implementation

### Authentication and Authorization
- **JWT Tokens:** Stateless authentication with refresh tokens
- **Role-Based Access:** GM, Player, and Observer roles
- **Permission System:** Granular permissions for resources
- **Session Security:** Secure session management with Redis

### Data Protection
- **Input Validation:** Comprehensive input sanitization
- **SQL Injection Prevention:** Parameterized queries only
- **XSS Protection:** Output encoding and CSP headers
- **File Upload Security:** Virus scanning and type validation

### Privacy Controls
- **Data Minimization:** Collect only necessary data
- **User Consent:** Explicit consent for data processing
- **Data Retention:** Configurable data retention policies
- **Export/Delete:** User data export and deletion capabilities

## Performance and Scalability

### Performance Targets
- **API Response Time:** < 200ms for database queries, < 2s for AI generation
- **Concurrent Users:** Support 1-15 concurrent users per instance
- **Database Queries:** < 100ms for complex queries
- **Audio Processing:** Real-time transcription with < 5s delay
- **Search Performance:** Sub-second fuzzy search results
- **AI Generation:** < 2s for content generation requests

### Scaling Strategies
- **Horizontal Scaling:** Stateless API servers behind load balancer
- **Database Scaling:** Read replicas and connection pooling
- **Caching:** Multi-level caching strategy
- **Background Processing:** Async task processing with Celery

### Monitoring and Observability
- **Metrics Collection:** Prometheus metrics for all services
- **Distributed Tracing:** OpenTelemetry for request tracing
- **Log Aggregation:** Structured logging with correlation IDs
- **Health Checks:** Comprehensive health monitoring

## Testing Strategy

### Unit Testing
- **Framework:** pytest with asyncio support
- **Coverage Target:** 90% code coverage for business logic
- **Mocking:** Mock external dependencies for isolation
- **Fixtures:** Shared test data and setup utilities

### Integration Testing
- **Database Testing:** TestContainers for isolated database tests
- **API Testing:** Full request/response cycle testing
- **WebSocket Testing:** Real-time communication testing
- **External Service Mocking:** Mock AI and audio processing services

### Load Testing
- **Framework:** Locust for load testing scenarios
- **Scenarios:** Typical user workflows and edge cases
- **Performance Baseline:** Establish performance benchmarks
- **Continuous Testing:** Automated performance regression testing

## Deployment and Operations

### Environment Configuration
- **Configuration Management:** Environment-based config
- **Secret Management:** External secret storage
- **Feature Flags:** Runtime feature toggling
- **Database Migrations:** Automated migration deployment

### Monitoring and Alerting
- **Application Metrics:** Custom business metrics
- **Infrastructure Metrics:** System resource monitoring
- **Alert Rules:** Proactive alerting for critical issues
- **Dashboard Creation:** Grafana dashboards for operations