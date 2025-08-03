# Frontend - CLAUDE.md

This file provides frontend-specific guidance for GameMaster's Companion React application development.

## Overview

The GMC frontend is a React application with TypeScript designed for multi-device collaboration. It emphasizes real-time features, role-based access control, and responsive design for both Game Masters and players.

## Technology Stack

### Core Technologies
- **React 18+** with TypeScript
- **Tailwind CSS** for styling (mobile-first responsive design)
- **WebSocket** integration for real-time collaboration
- **Service Workers** for offline functionality
- **React Native compatibility** for future mobile app development

### Key Design Principles
- **Multi-Device Collaboration**: Real-time synchronization across GM and player devices
- **Role-Based UI**: Different interfaces for GMs vs players with appropriate information filtering
- **Responsive Design**: Mobile-first approach with tablet and desktop optimization
- **Accessibility**: WCAG 2.1 AA compliance for inclusive design
- **Offline Support**: Service Worker implementation for offline functionality

## Development Environment

### Frontend Service Access
```bash
# Start frontend development environment
./infrastructure/scripts/dev-workflow.sh port-forward frontend

# Access frontend
# http://localhost:3000
```

### Development Commands
```bash
# View frontend logs
./infrastructure/scripts/dev-workflow.sh logs frontend

# Follow frontend logs in real-time
./infrastructure/scripts/dev-workflow.sh logs frontend follow

# Restart frontend service
./infrastructure/scripts/dev-workflow.sh restart frontend
```

## Architecture and Features

### Core UI Components

**Character Management Interface:**
- Character profiles with customizable fields
- Voice characteristics and roleplay notes for GMs
- Achievement and story arc tracking
- Relationship mapping between characters
- Character evolution timeline
- Import functionality from D&D Beyond

**World Building Interface:**
- Multi-level location hierarchy (world → region → city → district → building → room)
- Environmental conditions and atmosphere notes
- Population and demographic data
- Integration with battle map systems/VTTs

**Live Session Interface:**
- Real-time audio processing visualization
- Keyword detection and reference lookup display
- Combat tracking and initiative management
- Real-time transcription with speaker identification
- Automatic in-character vs out-of-character annotations

**Multi-Device Collaboration Features:**
- Role-based content filtering (GM vs Player views)
- Real-time synchronization of shared information
- Device-specific UI optimization
- Session state management across devices
- Push maps/handouts to all player devices simultaneously

### Real-Time Features

**WebSocket Integration:**
- Real-time session updates
- Live character sheet synchronization
- Multi-device session state management
- Real-time audio processing results display

**Offline Capabilities:**
- Service Worker for offline functionality
- Local data caching
- Sync when reconnected
- Offline character sheet access

### UI/UX Considerations

**Responsive Design:**
- Mobile-first development approach
- Tablet optimization for session management
- Desktop optimization for GM preparation
- Touch-friendly interfaces for mobile devices

**Accessibility:**
- Screen reader compatibility
- Keyboard navigation support
- High contrast mode support
- Font size adjustment capabilities

**Role-Based Access:**
- GM interface: Full access to all campaign data, NPC notes, plot information
- Player interface: Character-specific data, public world information, session notes
- Real-time permission switching during sessions

## API Integration

### Backend API Endpoints
```bash
# API base URL (development)
http://localhost:8000

# API documentation
http://localhost:8000/docs
```

### Key API Integration Points
- **Authentication**: JWT-based authentication with role management
- **Character Management**: CRUD operations for PCs and NPCs
- **Session Management**: Real-time session data and transcription
- **Search**: Fuzzy search for fantasy names and game terminology
- **AI Integration**: Content generation and session summarization

### WebSocket Connections
- **Session Updates**: Real-time session state changes
- **Audio Processing**: Live transcription and keyword detection results
- **Collaboration**: Multi-device synchronization
- **Notifications**: Real-time alerts and updates

## Component Development Guidelines

### Component Structure
- Follow React functional components with hooks
- Use TypeScript for all component props and state
- Implement proper error boundaries
- Design components for React Native compatibility

### State Management
- Use React Context for global application state
- Local component state for UI-specific data
- WebSocket state management for real-time features
- Offline state synchronization

### Styling Guidelines
- Tailwind CSS for consistent styling
- Mobile-first responsive design
- Design system components for consistency
- Dark mode support for extended gaming sessions

## Testing Strategy

### Frontend Testing
```bash
# Run frontend tests (when implemented)
# npm test (from frontend directory)

# E2E testing with real backend services
# npm run e2e (when implemented)
```

### Testing Focus Areas
- Component rendering and interactions
- Real-time WebSocket functionality
- Role-based access control
- Responsive design across devices
- Offline functionality
- Cross-browser compatibility

## Performance Optimization

### Key Performance Areas
- **Real-time Updates**: Efficient WebSocket message handling
- **Large Datasets**: Virtual scrolling for character/session lists
- **Image Loading**: Lazy loading for maps and character portraits
- **Bundle Size**: Code splitting for feature-based loading
- **Mobile Performance**: Touch interaction optimization

### Development Performance Tools
```bash
# Monitor frontend performance during development
./infrastructure/scripts/dev-workflow.sh logs frontend

# Check resource usage
kubectl top pods -n gmc-dev -l app.kubernetes.io/component=frontend
```

## Security Considerations

### Frontend Security
- JWT token management and refresh
- Secure WebSocket connections
- XSS prevention
- CSRF protection
- Secure local storage of sensitive data

### Role-Based Security
- Client-side permission checking (with server validation)
- Secure data filtering for different user roles
- Session-based access control
- Secure multi-device authentication

## Integration Points

### External Service Integration
- **D&D Beyond API**: Character import functionality
- **Discord Webhooks**: Session summary posting
- **VTT Integration**: Battle map and token synchronization

### AI Service Integration
- **Content Generation**: UI for AI-powered NPC/location generation
- **Session Summarization**: Display of AI-generated session summaries
- **Audio Processing**: Real-time transcription display
- **Search Enhancement**: AI-powered search suggestions

## Development Workflow

### Local Development Setup
```bash
# Ensure development environment is running
./infrastructure/scripts/dev-workflow.sh status

# Access frontend development server
./infrastructure/scripts/dev-workflow.sh port-forward frontend
```

### Code Development Process
1. Work with containerized development environment
2. Use real backend services for full-stack testing
3. Test responsive design across multiple device sizes
4. Validate role-based access control
5. Test real-time features with multiple browser windows

### Debugging Frontend Issues
```bash
# Check frontend container logs
./infrastructure/scripts/dev-workflow.sh logs frontend follow

# Access frontend container for debugging
kubectl exec -it deployment/gmc-dev-frontend -n gmc-dev -- /bin/bash

# Check frontend service connectivity
curl http://localhost:3000
```

## Future Considerations

### Mobile App Development
- React Native implementation path
- Shared component library between web and mobile
- Platform-specific optimizations
- Native device feature integration

### Progressive Web App Features
- Push notifications for session updates
- Background sync for offline changes
- App-like installation on mobile devices
- Advanced caching strategies

### Advanced Features
- Voice command integration
- Augmented reality for map visualization
- Advanced gesture controls for mobile
- Multi-language support for international users