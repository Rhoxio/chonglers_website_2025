#!/bin/bash

echo "🔧 Fixing Ruby Environment (RVM → rbenv)"
echo "========================================"

# Step 1: Remove RVM completely
echo "📦 Removing RVM installation..."
if [ -d "$HOME/.rvm" ]; then
    echo "   Removing ~/.rvm directory..."
    rm -rf "$HOME/.rvm"
    echo "   ✅ RVM directory removed"
else
    echo "   ℹ️  RVM directory not found"
fi

# Step 2: Clean up shell configuration files
echo ""
echo "🧹 Cleaning up shell configuration..."

# Backup existing files
cp ~/.bash_profile ~/.bash_profile.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Create clean bash_profile with only rbenv
cat > ~/.bash_profile << 'EOF'
# rbenv configuration
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Load bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
EOF

echo "   ✅ Created clean ~/.bash_profile"

# Step 3: Verify rbenv installation
echo ""
echo "🔍 Verifying rbenv installation..."
if command -v rbenv &> /dev/null; then
    echo "   ✅ rbenv is installed"
    echo "   📍 rbenv location: $(which rbenv)"
    echo "   📍 rbenv version: $(rbenv --version)"
else
    echo "   ❌ rbenv not found. Please install rbenv first:"
    echo "      brew install rbenv ruby-build"
    exit 1
fi

# Step 4: Check Ruby versions
echo ""
echo "🔍 Checking Ruby versions..."
echo "   Available Ruby versions:"
rbenv versions

echo ""
echo "   Current Ruby version:"
rbenv version

# Step 5: Clean up gem environment
echo ""
echo "🧹 Cleaning up gem environment..."
unset GEM_HOME
unset GEM_PATH
unset MY_RUBY_HOME
unset IRBRC

# Step 6: Instructions for next steps
echo ""
echo "🎉 Environment cleanup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Close and reopen your terminal"
echo "   2. Run: source ~/.bash_profile"
echo "   3. Verify with: ruby --version"
echo "   4. Verify with: gem env | grep INSTALLATION"
echo ""
echo "⚠️  If you still see RVM paths, run:"
echo "   unset GEM_HOME GEM_PATH MY_RUBY_HOME IRBRC"
echo "   export PATH=\"\$HOME/.rbenv/bin:\$PATH\""
echo "   eval \"\$(rbenv init -)\""
