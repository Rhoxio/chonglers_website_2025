# Chonglers Website 2025

A Rails 8.0 application for the Chonglers guild, featuring World of Warcraft guild management, Warcraft Logs integration, authentication via OAuth providers, and AI chat capabilities.

## 🚀 Quick Start

### Prerequisites

- **Ruby**: 3.4.3 (see `.ruby-version`)
- **PostgreSQL**: 9.3 or higher
- **Node.js**: For asset compilation (Rails 8.0 with importmaps)

### 1. Clone and Setup

```bash
git clone <repository-url>
cd chonglers-website-2025
bundle install
```

### 2. Database Setup

```bash
# Install PostgreSQL if needed (macOS)
brew install postgresql
brew services start postgresql

# Create and setup databases
rails db:create
rails db:migrate
rails db:seed  # if seed data exists
```

### 3. Environment Configuration

Create a `.env` file in the project root:

```bash
# Database
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432

# OAuth Providers (optional - configure as needed)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
DISCORD_CLIENT_ID=your_discord_client_id
DISCORD_CLIENT_SECRET=your_discord_client_secret

# Warcraft Logs API (for guild features)
WARCRAFT_LOGS_CLIENT_ID=your_warcraft_logs_client_id
WARCRAFT_LOGS_CLIENT_SECRET=your_warcraft_logs_client_secret

# AI Integration (optional)
OPENAI_API_KEY=your_openai_api_key

# Cloudinary (for image uploads)
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
```

### 4. Run the Application

```bash
# Start the development server
rails server
# or use foreman for process management
foreman start -f Procfile.dev

# Visit http://localhost:3000
```

## 🏗️ Architecture Overview

### Core Features

- **Rails 8.0** with modern stack (Turbo, Stimulus, Importmaps)
- **PostgreSQL** database with ActiveRecord
- **Devise** authentication with OAuth providers (Google, GitHub, Discord)
- **Warcraft Logs API** integration for guild analytics
- **AI Chat** capabilities (OpenAI integration)
- **RSpec** testing framework with FactoryBot

### Key Components

- **Guild Management**: Track guild members, attendance, and performance
- **Warcraft Logs Integration**: Modular query system for raid analytics
- **OAuth Authentication**: Multiple provider support
- **Admin Panel**: Guild administration features
- **Responsive Design**: SCSS styling system

## 📁 Project Structure

```
app/
├── controllers/          # Rails controllers
│   ├── application_controller.rb
│   ├── home_controller.rb
│   └── admin_controller.rb
├── models/              # ActiveRecord models
│   ├── application_record.rb
│   └── user.rb
├── queries/             # Warcraft Logs API queries
│   └── warcraft_logs/
│       ├── base_client.rb
│       ├── report_query.rb
│       ├── encounter_query.rb
│       ├── performance_query.rb
│       └── attendance_query_new.rb
├── services/            # Business logic services
│   └── warcraft_logs_analytics_service.rb
└── views/               # ERB templates
```

## 🧪 Testing

```bash
# Run the full test suite
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/user_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## 🔧 Development

### Database Operations

```bash
# Reset database
rails db:drop db:create db:migrate

# Generate new migration
rails generate migration AddFieldToModel field:type

# Run migrations
rails db:migrate
```

### Console Access

```bash
# Rails console
rails console

# Database console
rails dbconsole
```

### Code Quality

```bash
# Check for security vulnerabilities
bundle audit

# Code formatting (if rubocop is added)
rubocop
```

## 🌐 API Integrations

### Warcraft Logs Setup

1. Register at [Warcraft Logs](https://www.warcraftlogs.com/api)
2. Create a new application
3. Add client credentials to `.env`
4. Test connection: `WarcraftLogs::GuildQuery.members(guild_id)`

### OAuth Provider Setup

#### Google OAuth
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 credentials
3. Add `http://localhost:3000/users/auth/google_oauth2/callback` to authorized redirects

#### GitHub OAuth
1. Visit [GitHub Developer Settings](https://github.com/settings/developers)
2. Create a new OAuth App
3. Set authorization callback URL to `http://localhost:3000/users/auth/github/callback`

#### Discord OAuth
1. Visit [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Add redirect URI: `http://localhost:3000/users/auth/discord/callback`

## 🤖 AI Chat Integration

The application includes AI chat capabilities. See [AI_CHAT_INTEGRATION_GUIDE.md](AI_CHAT_INTEGRATION_GUIDE.md) for detailed setup instructions.

Quick setup:
1. Get OpenAI API key from [OpenAI Platform](https://platform.openai.com/)
2. Add to `.env`: `OPENAI_API_KEY=your_key_here`
3. Install gem: `gem "ruby-openai"`

## 📊 Warcraft Logs Analytics

The application features a modular Warcraft Logs integration. See [MODULAR_ARCHITECTURE.md](MODULAR_ARCHITECTURE.md) for detailed architecture documentation.

### Quick Usage

```ruby
# Get guild attendance summary
WarcraftLogsAnalyticsService.get_attendance_summary(guild_id, start_date)

# Get encounter statistics
WarcraftLogs::EncounterQuery.get_encounter_stats(guild_id, start_date)

# Get performance data
WarcraftLogs::PerformanceQuery.get_guild_performance(guild_id, start_date)
```

## 🚢 Deployment

### Railway Deployment (Recommended)

This application is configured for easy deployment on [Railway](https://railway.app/).

#### 1. Setup Railway Project

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Create new project
railway new
```

#### 2. Add PostgreSQL Database

1. In Railway dashboard, add PostgreSQL service
2. Railway will automatically provide `DATABASE_URL`

#### 3. Configure Environment Variables

Set these variables in Railway dashboard:

```bash
# Required
RAILS_MASTER_KEY=your_rails_master_key
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name

# OAuth (configure as needed)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
DISCORD_CLIENT_ID=your_discord_client_id
DISCORD_CLIENT_SECRET=your_discord_client_secret

# API Keys
WARCRAFT_LOGS_CLIENT_ID=your_warcraft_logs_client_id
WARCRAFT_LOGS_CLIENT_SECRET=your_warcraft_logs_client_secret
OPENAI_API_KEY=your_openai_api_key
```

#### 4. Deploy

```bash
# Connect to Railway project
railway link

# Deploy
railway up
```

#### 5. Update OAuth Redirect URIs

Update your OAuth applications with production URLs:
- Google: `https://your-app.railway.app/users/auth/google_oauth2/callback`
- GitHub: `https://your-app.railway.app/users/auth/github/callback`
- Discord: `https://your-app.railway.app/users/auth/discord/callback`

### Manual Environment Variables for Production

Ensure all required environment variables are set:

- `DATABASE_URL` (automatically provided by Railway PostgreSQL)
- `RAILS_MASTER_KEY` (get from `config/master.key`)
- OAuth provider credentials
- API keys (Warcraft Logs, OpenAI, Cloudinary)

### Docker Deployment (Alternative)

```bash
# Build image
docker build -t chonglers-website .

# Run with environment variables
docker run -p 3000:3000 --env-file .env chonglers-website
```

## 🆘 Troubleshooting

### Common Issues

**Database Connection Issues**:
```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Reset database if needed
rails db:reset
```

**Bundle Install Issues**:
```bash
# Clear bundle cache
bundle clean --force
bundle install
```

**Asset Issues**:
```bash
# Clear asset cache
rails assets:clean assets:precompile
```

### Getting Help

- Check existing [Issues](https://github.com/your-repo/issues)
- Review [AI Chat Integration Guide](AI_CHAT_INTEGRATION_GUIDE.md)
- Review [Modular Architecture Documentation](MODULAR_ARCHITECTURE.md)

## 🔄 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Run tests: `bundle exec rspec`
4. Commit changes: `git commit -am 'Add new feature'`
5. Push to branch: `git push origin feature/new-feature`
6. Submit a Pull Request

## 📄 License

[Add your license information here]

---

**Built for the Chonglers Guild** | World of Warcraft | 2025
