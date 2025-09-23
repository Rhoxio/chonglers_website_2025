# AI Chat Integration Guide for Chonglers Website

## 🤖 **OpenAI ChatGPT API Access**

### **Getting Started:**
1. **Visit**: https://platform.openai.com/
2. **Sign up** for an account (or log in if you have one)
3. **Go to API section** in the dashboard
4. **Add billing information** (required for API access)
5. **Generate API keys** in the API keys section

### **Pricing (as of 2024):**
- **GPT-4**: ~$0.03 per 1K input tokens, ~$0.06 per 1K output tokens
- **GPT-3.5 Turbo**: ~$0.0015 per 1K input tokens, ~$0.002 per 1K output tokens
- **Minimum usage**: Usually $5-10 to start

### **API Key Security:**
- Store in your `.env` file: `OPENAI_API_KEY=your_key_here`
- Never commit API keys to git
- Use environment variables in production

## 🔄 **Alternative AI Services**

### **Anthropic Claude:**
- **Website**: https://console.anthropic.com/
- **Pricing**: Similar to GPT-4
- **Good for**: Long conversations, analysis

### **Google Gemini:**
- **Website**: https://makersuite.google.com/
- **Pricing**: Often has free tiers
- **Good for**: Multimodal (text + images)

### **Open Source Options:**
- **Ollama**: Run models locally
- **Hugging Face**: Free tier available
- **Groq**: Fast inference, good pricing

## 💡 **Implementation Ideas for Chonglers**

### **Potential Use Cases:**
1. **Guild Chat Bot**: Answer common questions
2. **Raid Strategy Helper**: AI-powered raid guides
3. **Character Build Advisor**: Class/spec recommendations
4. **Guild Recruitment**: AI screening questions
5. **Content Generation**: Guild announcements, guides

### **Technical Integration:**
```ruby
# Example gem for OpenAI
gem "ruby-openai"

# In your controller
def chat_with_ai
  client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [{ role: "user", content: params[:message] }]
    }
  )
end
```

## 🛠️ **Implementation Approaches**

### **Option A: Simple Chat Interface**
```ruby
# Add to your Gemfile
gem "ruby-openai"

# Create a chat controller
class ChatController < ApplicationController
  def index
    # Chat interface
  end
  
  def send_message
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    # Inject context (guild info, rules, etc.)
    context = "You are a helpful assistant for the Chonglers guild. Guild rules: #{guild_rules}. Recent events: #{recent_events}"
    
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: context },
          { role: "user", content: params[:message] }
        ]
      }
    )
    
    render json: { response: response.dig("choices", 0, "message", "content") }
  end
end
```

### **Option B: File Upload + Chat**
```ruby
# Upload files and inject into chat context
def upload_file
  file_content = File.read(params[:file].path)
  
  # Store file content for later use in chat
  session[:uploaded_files] ||= []
  session[:uploaded_files] << {
    name: params[:file].original_filename,
    content: file_content
  }
end

def send_message
  # Include uploaded files in context
  file_context = session[:uploaded_files].map { |f| "#{f[:name]}: #{f[:content]}" }.join("\n\n")
  
  # Send to ChatGPT with file context
end
```

## 🎨 **Frontend Chat Interface**

### **Simple HTML/CSS Chat Widget**
```erb
<!-- In your view -->
<div class="chat-widget">
  <div class="chat-header">
    <h3>Chonglers AI Assistant</h3>
  </div>
  <div class="chat-messages" id="chatMessages">
    <!-- Messages appear here -->
  </div>
  <div class="chat-input">
    <input type="text" id="messageInput" placeholder="Ask about guild rules, raids, etc...">
    <button onclick="sendMessage()">Send</button>
  </div>
</div>
```

### **JavaScript for Real-time Chat**
```javascript
function sendMessage() {
  const input = document.getElementById('messageInput');
  const message = input.value;
  
  fetch('/chat/send_message', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({ message: message })
  })
  .then(response => response.json())
  .then(data => {
    // Add message to chat
    addMessageToChat('user', message);
    addMessageToChat('assistant', data.response);
    input.value = '';
  });
}
```

## 📁 **File Injection Examples**

### **Guild Documents**
- **Raid schedules** → "When is our next Mythic+ run?"
- **Guild rules** → "What's our loot policy?"
- **Class guides** → "Best rotation for Fire Mage?"

### **Character Data**
- **Gear lists** → "What should I upgrade next?"
- **Achievement progress** → "What achievements am I missing?"

## 🚀 **Next Steps**

1. **Choose your AI provider** (OpenAI is most popular)
2. **Set up API access** and billing
3. **Add API key to your `.env` file**
4. **Install relevant gem** (like `ruby-openai`)
5. **Start with simple chat functionality**

## 📝 **Implementation Checklist**

- [ ] Add `ruby-openai` gem to Gemfile
- [ ] Create chat controller with file upload capability
- [ ] Build chat widget that matches dark theme
- [ ] Set up environment variables for API keys
- [ ] Test basic chat functionality
- [ ] Add file upload and context injection
- [ ] Style chat widget to match Chonglers theme
- [ ] Add chat to admin panel or as floating widget

## 🔧 **Environment Variables Needed**

```bash
# Add to .env file
OPENAI_API_KEY=your_openai_api_key_here
```

## 📚 **Useful Resources**

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Ruby OpenAI Gem](https://github.com/alexrudall/ruby-openai)
- [OpenAI Pricing](https://openai.com/pricing)
- [ChatGPT API Examples](https://platform.openai.com/docs/guides/text-generation)

---

*Created for Chonglers Guild Website - 2025*
