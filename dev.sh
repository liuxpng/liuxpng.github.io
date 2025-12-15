#!/bin/bash

# Jekyll Blog Development Helper Script

case "$1" in
  start)
    echo "🚀 Starting Jekyll blog in development mode..."
    docker-compose up
    ;;

  start-d)
    echo "🚀 Starting Jekyll blog in background..."
    docker-compose up -d
    echo "✅ Blog is running at http://localhost:4000"
    echo "📝 View logs: ./dev.sh logs"
    ;;

  stop)
    echo "🛑 Stopping Jekyll blog..."
    docker-compose down
    ;;

  restart)
    echo "🔄 Restarting Jekyll blog..."
    docker-compose restart
    ;;

  logs)
    echo "📋 Showing logs (Ctrl+C to exit)..."
    docker-compose logs -f
    ;;

  clean)
    echo "🧹 Cleaning build cache and stopping containers..."
    docker-compose down -v
    echo "✅ Cache cleaned"
    ;;

  bash)
    echo "💻 Opening bash in Jekyll container..."
    docker-compose exec jekyll bash
    ;;

  build)
    echo "🔨 Building site..."
    docker-compose exec jekyll bundle exec jekyll build
    ;;

  *)
    echo "Jekyll Blog Development Helper"
    echo ""
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start      - Start blog (foreground, with logs)"
    echo "  start-d    - Start blog in background"
    echo "  stop       - Stop blog"
    echo "  restart    - Restart blog"
    echo "  logs       - View logs"
    echo "  clean      - Clean cache and stop"
    echo "  bash       - Open bash in container"
    echo "  build      - Build site"
    echo ""
    echo "After starting, visit: http://localhost:4000"
    ;;
esac
