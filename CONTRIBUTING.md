# Contributing to Yes

Thank you for your interest in contributing to Yes! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- Ruby >= 3.2.0
- Docker and Docker Compose (for PostgreSQL and Redis)
- Bundler

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yousty/yes.git
   cd yes
   ```

2. Start the required services:
   ```bash
   docker compose up -d
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Set up databases:
   ```bash
   ./bin/setup_db
   ```

### Project Structure

```
yes/                      # Root gem (meta-package)
├── yes-core/             # Core event sourcing framework
│   └── spec/dummy/       # Dummy Rails app for integration tests
├── yes-command-api/      # Command API engine
│   └── spec/dummy/       # Dummy Rails app for integration tests
└── yes-read-api/         # Read API engine
    └── spec/dummy/       # Dummy Rails app for integration tests
```

## Running Tests

Run specs for a specific gem:

```bash
cd yes-core && bundle exec rspec
cd yes-command-api && bundle exec rspec
cd yes-read-api && bundle exec rspec
```

Or from root for all gems:

```bash
bundle exec rspec yes-core/spec
bundle exec rspec yes-command-api/spec
bundle exec rspec yes-read-api/spec
```

## Running RuboCop

```bash
bundle exec rubocop
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes with tests
4. Ensure all specs pass and RuboCop is clean
5. Submit a pull request

### Guidelines

- Follow the existing code style and conventions
- Add tests for all new functionality
- Keep commits focused and well-described
- Update documentation if you change public APIs

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
