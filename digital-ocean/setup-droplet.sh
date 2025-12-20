#!/bin/bash
set -e

echo "🏐 Volleyer Droplet Setup Script"
echo "================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run this script as root (use sudo)"
    exit 1
fi

SHARED_REPO_URL="https://github.com/Bielov-Team-Track/shared"
DO_REGISTRY_NAME="volleyer"
# Prompt for required variables

echo "📝 Please provide the following information:"
read -p "GitHub Personal Access Token: " GITHUB_PAT 

echo ""
echo "🔧 Setting up Volleyer infrastructure..."

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📦 Installing Git..."
    apt-get update
    apt-get install -y git
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    UBUNTU_CODENAME=$(lsb_release -cs)
    if [ "$UBUNTU_CODENAME" = "oracular" ]; then
        UBUNTU_CODENAME="noble"
        echo "Using noble repository for Ubuntu 25.04 compatibility"
    fi
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker is already installed"
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p /opt/volleyer
cd /opt/volleyer

# Clone shared repository
echo "📥 Cloning shared repository..."
if [ -d "shared" ]; then
    echo "🔄 Updating existing shared repository..."
    cd shared
    git pull
    cd ..
else
    # Clone with PAT authentication
    REPO_WITH_PAT=$(echo $SHARED_REPO_URL | sed "s|https://|https://$GITHUB_PAT@|")
    git clone $REPO_WITH_PAT shared
fi

# Navigate to deployment directory
cd shared/deployment

# Create .env file
echo "⚙️ Creating environment configuration..."
cat > .env << EOF
# Digital Ocean Container Registry
DO_REGISTRY_NAME=$DO_REGISTRY_NAME
EOF

# Set permissions
chmod +x deploy-stack.sh 2>/dev/null || echo "deploy-stack.sh not found, skipping chmod"

# Create Docker network
echo "🌐 Creating Docker network..."
docker network ls | grep volleyer-network || docker network create volleyer-network

# Start nginx proxy
echo "🚀 Starting nginx proxy..."
docker compose -f docker-compose.prod.yml up -d nginx

# Show status
echo ""
echo "📊 Current Status:"
docker compose -f docker-compose.prod.yml ps

# Cleanup PAT from bash history
history -d $(history 1)

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📍 Deployment directory: /opt/volleyer/shared/deployment"
echo "🔧 Configuration file: /opt/volleyer/shared/deployment/.env"
echo "🌐 Network: volleyer-network"
echo "🔄 Nginx proxy: Running"
echo ""
echo "🚀 Your services can now deploy using the docker-compose stack!"
echo ""
echo "Test endpoints:"
echo "  - Nginx: http://$(curl -s ifconfig.me)/"
echo "  - Auth health (after deployment): http://$(curl -s ifconfig.me)/api/auth/health"
echo "  - Events health (after deployment): http://$(curl -s ifconfig.me)/api/events/health"