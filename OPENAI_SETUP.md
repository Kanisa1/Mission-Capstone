# OpenAI Chat Assistant Setup Guide

This guide explains how to set up the OpenAI API integration for the MineralTrace AI chat assistant.

## Step 1: Get Your OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Sign up for an account or log in
3. Navigate to **API keys** section
4. Click **Create new secret key**
5. Copy the key (it starts with `sk-`)
6. **Important**: Save this key securely - you won't be able to see it again!

## Step 2: Add the API Key to Your Environment

### Option A: Using .env file (Recommended for Development)

1. Create a `.env` file in the project root (`Mission-Capstone/`)
   ```
   OPENAI_API_KEY=sk-your-actual-api-key-here
   ```

2. The Python `dotenv` package will automatically load it

### Option B: Using Environment Variables (Recommended for Production)

```bash
# Windows PowerShell
$env:OPENAI_API_KEY = "sk-your-actual-api-key-here"

# Windows Command Prompt
set OPENAI_API_KEY=sk-your-actual-api-key-here

# Linux/Mac
export OPENAI_API_KEY=sk-your-actual-api-key-here
```

### Option C: Using Docker (.env in container)

Add to your docker environment:
```dockerfile
ENV OPENAI_API_KEY=sk-your-actual-api-key-here
```

## Step 3: Install OpenAI Package

```bash
# In your Python virtual environment
pip install -r API/requirements.txt

# Or manually install
pip install openai>=1.3.0
```

## Step 4: Test the Configuration

1. Start the API server:
   ```bash
   cd API
   python api.py
   ```

2. Look for this message in startup:
   ```
   ✓ OpenAI API configured - Chat assistant will use GPT-3.5-turbo
   ```

3. Test the endpoint:
   ```bash
   curl -X POST "http://localhost:8000/api/chat/assist" \
     -H "Content-Type: application/json" \
     -d '{
       "query": "How do I scan a mineral?",
       "context": "scanning"
     }'
   ```

## Cost Information

- **GPT-3.5-turbo** is the most affordable OpenAI model
- Pricing as of 2024:
  - Input: $0.50 per 1M tokens
  - Output: $1.50 per 1M tokens
- Typical chat: 100-200 tokens per message = ~$0.001-0.003 per query
- Set up usage limits in [OpenAI Dashboard](https://platform.openai.com/account/billing/overview)

## Fallback Behavior

If OpenAI is not configured or available:
- The system will automatically fall back to the knowledge base
- Users will still get helpful responses using pre-written guides
- No errors or interruptions - seamless experience

## Troubleshooting

### Issue: "OPENAI_API_KEY environment variable not set"

**Solution**: Make sure you've set the environment variable correctly:
1. Verify the key is in your `.env` file or system environment
2. Restart the API server
3. Check startup logs for confirmation

### Issue: "Invalid API key"

**Solution**: Verify your API key:
1. Go to [OpenAI API keys](https://platform.openai.com/api-keys)
2. Confirm your key starts with `sk-`
3. Check that you haven't accidentally modified it
4. Create a new key if needed

### Issue: "Rate limit exceeded"

**Solution**: You're sending too many requests too quickly
1. Add delays between requeries
2. Check your usage at [OpenAI Billing](https://platform.openai.com/account/billing/overview)
3. Upgrade your plan if needed

### Issue: Chat still uses knowledge base even after setting key

**Solution**: The server needs to be restarted
1. Stop the API server (Ctrl+C)
2. Verify your environment variable is set
3. Start the API server again

## Advanced Configuration

### Custom Model

To use a different OpenAI model, edit `api.py` in the `generate_ai_response` function:

```python
response = client.chat.completions.create(
    model="gpt-4",  # Change this to gpt-4, gpt-4-turbo, etc.
    messages=messages,
    temperature=0.7,
    max_tokens=500,
)
```

### Adjust Response Parameters

In the same function:
- **temperature**: 0.0-2.0 (lower = more focused, higher = more creative)
- **max_tokens**: Maximum response length (lower = faster, higher = more detailed)

## Security Best Practices

✓ **Do:**
- Keep your API key private
- Use environment variables, never hardcode keys
- Rotate keys regularly
- Set usage limits in OpenAI Dashboard
- Monitor billing for unusual activity

✗ **Don't:**
- Commit `.env` file with keys to git (already in .gitignore)
- Share your API key
- Expose the key in client-side code
- Use the same key across all environments

## Monitoring Usage

1. Visit [OpenAI Usage Dashboard](https://platform.openai.com/account/usage/overview)
2. Set spending limits at [Billing Settings](https://platform.openai.com/account/billing/limits)
3. Check monthly costs to optimize if needed

## Questions or Issues?

- OpenAI Docs: https://platform.openai.com/docs
- OpenAI Support: https://help.openai.com
- MineralTrace Issues: Check your project logs
