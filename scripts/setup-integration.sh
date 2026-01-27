#!/bin/bash

# ============================================================
# GitLab-Slack-Notion Integration Setup Script
# ============================================================
# This script helps you set up the n8n instance with GitLab,
# Slack, and Notion integration.
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================"
}

# Check if .env file exists
check_env_file() {
    if [ ! -f ".env" ]; then
        print_info "Creating .env file from .env.example..."
        cp .env.example .env
        print_success ".env file created!"
    else
        print_info ".env file already exists."
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_success "Docker is installed."
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    print_success "Docker Compose is available."
}

# Interactive setup for integration settings
setup_integration() {
    print_header "GitLab-Slack-Notion Integration Setup"
    
    echo ""
    echo "This script will help you configure the integration settings."
    echo "Press Enter to skip any setting you want to configure later."
    echo ""
    
    # GitLab settings
    print_header "GitLab Configuration"
    
    read -p "GitLab Server URL (e.g., https://gitlab.company.com): " GITLAB_URL
    if [ -n "$GITLAB_URL" ]; then
        sed -i "s|# GITLAB_URL=.*|GITLAB_URL=$GITLAB_URL|" .env
        print_success "GitLab URL configured."
    fi
    
    read -p "GitLab Access Token (glpat-...): " GITLAB_ACCESS_TOKEN
    if [ -n "$GITLAB_ACCESS_TOKEN" ]; then
        sed -i "s|# GITLAB_ACCESS_TOKEN=.*|GITLAB_ACCESS_TOKEN=$GITLAB_ACCESS_TOKEN|" .env
        print_success "GitLab Access Token configured."
    fi
    
    read -p "GitLab Project ID (numeric): " GITLAB_PROJECT_ID
    if [ -n "$GITLAB_PROJECT_ID" ]; then
        sed -i "s|# GITLAB_PROJECT_ID=.*|GITLAB_PROJECT_ID=$GITLAB_PROJECT_ID|" .env
        print_success "GitLab Project ID configured."
    fi
    
    # Slack settings
    print_header "Slack Configuration"
    
    read -p "Slack Bot Token (xoxb-...): " SLACK_BOT_TOKEN
    if [ -n "$SLACK_BOT_TOKEN" ]; then
        sed -i "s|# SLACK_BOT_TOKEN=.*|SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN|" .env
        print_success "Slack Bot Token configured."
    fi
    
    read -p "Slack Channel (e.g., #issue-notifications): " SLACK_CHANNEL
    if [ -n "$SLACK_CHANNEL" ]; then
        sed -i "s|# SLACK_CHANNEL=.*|SLACK_CHANNEL=$SLACK_CHANNEL|" .env
        print_success "Slack Channel configured."
    fi
    
    # Notion settings
    print_header "Notion Configuration"
    
    read -p "Notion API Key (secret_...): " NOTION_API_KEY
    if [ -n "$NOTION_API_KEY" ]; then
        sed -i "s|# NOTION_API_KEY=.*|NOTION_API_KEY=$NOTION_API_KEY|" .env
        print_success "Notion API Key configured."
    fi
    
    read -p "Notion Database ID: " NOTION_DATABASE_ID
    if [ -n "$NOTION_DATABASE_ID" ]; then
        sed -i "s|# NOTION_DATABASE_ID=.*|NOTION_DATABASE_ID=$NOTION_DATABASE_ID|" .env
        print_success "Notion Database ID configured."
    fi
    
    # Cloudflare Tunnel settings
    print_header "Cloudflare Tunnel Configuration (Optional)"
    echo "If you have a Cloudflare Tunnel token, enter it here."
    echo "Otherwise, you can use the quick tunnel script later."
    
    read -p "Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN
    if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        sed -i "s|# CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN|" .env
        print_success "Cloudflare Tunnel Token configured."
    fi
    
    print_success "Configuration complete!"
}

# Select hardware profile
select_profile() {
    print_header "Select Hardware Profile"
    
    echo ""
    echo "Please select your hardware configuration:"
    echo "  1) NVIDIA GPU"
    echo "  2) AMD GPU"
    echo "  3) CPU only"
    echo ""
    
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1) PROFILE="gpu-nvidia" ;;
        2) PROFILE="gpu-amd" ;;
        3) PROFILE="cpu" ;;
        *) 
            print_warning "Invalid choice. Defaulting to CPU."
            PROFILE="cpu"
            ;;
    esac
    
    print_success "Selected profile: $PROFILE"
}

# Start services
start_services() {
    print_header "Starting Services"
    
    print_info "Starting n8n and related services..."
    
    if docker compose --profile "$PROFILE" up -d; then
        print_success "Services started successfully!"
    else
        print_error "Failed to start services."
        exit 1
    fi
}

# Start with Cloudflare Tunnel
start_with_tunnel() {
    print_header "Starting with Cloudflare Tunnel"
    
    read -p "Do you want to start Cloudflare Tunnel as well? (y/n): " start_tunnel
    
    if [ "$start_tunnel" = "y" ] || [ "$start_tunnel" = "Y" ]; then
        if grep -q "CLOUDFLARE_TUNNEL_TOKEN=" .env && ! grep -q "# CLOUDFLARE_TUNNEL_TOKEN=" .env; then
            print_info "Starting with permanent Cloudflare Tunnel..."
            docker compose --profile "$PROFILE" --profile tunnel up -d
            print_success "Services started with Cloudflare Tunnel!"
        else
            print_info "No permanent tunnel token found. Starting quick tunnel..."
            print_warning "This tunnel URL will change each time you restart."
            docker compose --profile "$PROFILE" up -d
            ./scripts/expose-with-cloudflare.sh &
            print_success "Quick tunnel started! Check the output for your temporary URL."
        fi
    else
        docker compose --profile "$PROFILE" up -d
    fi
}

# Print next steps
print_next_steps() {
    print_header "Next Steps"
    
    echo ""
    echo "1. Open n8n in your browser:"
    echo "   ${GREEN}http://localhost:5678${NC}"
    echo ""
    echo "2. Create an admin account on first access"
    echo ""
    echo "3. Go to Settings > Credentials and configure:"
    echo "   - GitLab API"
    echo "   - Slack API"
    echo "   - Notion API"
    echo ""
    echo "4. Activate the integration workflows:"
    echo "   - GitLab-Slack-Notion Issue Sync"
    echo "   - GitLab Commit Issue Resolver"
    echo "   - Comment Sync"
    echo "   - Slack Issue Bot"
    echo ""
    echo "5. Configure webhooks in GitLab:"
    echo "   - Add webhook URL from n8n"
    echo "   - Select Push events and Issues events"
    echo ""
    echo "For detailed instructions, see:"
    echo "   - ${BLUE}docs/INTEGRATION_SETUP.md${NC}"
    echo "   - ${BLUE}docs/CLOUDFLARE_TUNNEL_SETUP.md${NC}"
    echo ""
    print_success "Setup complete! Enjoy your GitLab-Slack-Notion integration!"
}

# Main function
main() {
    print_header "Self-hosted AI Starter Kit - Integration Setup"
    
    # Check prerequisites
    check_docker
    check_docker_compose
    check_env_file
    
    # Ask if user wants interactive setup
    read -p "Do you want to run interactive integration setup? (y/n): " run_setup
    
    if [ "$run_setup" = "y" ] || [ "$run_setup" = "Y" ]; then
        setup_integration
    fi
    
    # Select hardware profile
    select_profile
    
    # Start services
    start_with_tunnel
    
    # Print next steps
    print_next_steps
}

# Run main function
main
