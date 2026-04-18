# Odoo AI Agent — MCP Server Client

Connect **Claude Desktop** (or any MCP-compatible AI) to your Odoo instance.
Once set up, you can ask Claude to search, analyze, create, update, or delete
any Odoo record using plain language.

---

## What Is This?

This folder contains a lightweight client that runs on **your device** (laptop or desktop).
It acts as a bridge between Claude Desktop and your Odoo server.

```
Your Device                          Odoo Server
───────────────                      ───────────────────────
Claude Desktop                       Odoo + Odoo AI Agent module
  └── server.py  ── HTTPS/HTTP ───►  /mcp/sse
      (this folder)
```

> **Your Odoo server** needs the `odoo_ai_agent` module installed.
> **Your device** only needs this folder + Python 3.

---

## Requirements

| Requirement | Version |
|---|---|
| Python | 3.10 or higher |
| Claude Desktop | Latest |
| Odoo | 17 or 19 (with `odoo_ai_agent` module installed) |

---

## Quick Setup

### macOS / Linux

```bash
cd mcp_server
bash setup.sh
```

### Windows

Double-click `setup.bat` or run in Command Prompt:

```cmd
cd mcp_server
setup.bat
```

The setup wizard will ask you 3 questions:

| Question | Example |
|---|---|
| Odoo URL | `https://your-odoo.com` or `http://localhost:8019` |
| Database name | `my_company_db` |
| API Token | `k9YYBckCjjU_8zI_...` |

After setup, **restart Claude Desktop** and look for the 🔨 hammer icon.

---

## How to Get an API Token

1. Open Odoo → go to **Odoo AI Agent → Configurations**
2. Open your configuration (or create one)
3. Click **"Generate Admin Token"** (full access) or **"Generate User Token"** (read-only)
4. Copy the token immediately — it is only shown once

---

## Files in This Folder

| File | Purpose |
|---|---|
| `server.py` | MCP stdio server — Claude Desktop runs this |
| `setup.sh` | One-time setup wizard for macOS / Linux |
| `setup.bat` | One-time setup wizard for Windows |
| `config.json` | Your connection settings (auto-generated, never commit this) |
| `requirements.txt` | Python dependencies (`mcp`, `requests`) |

---

## Supported AI Actions

Once connected, you can ask Claude:

| What you say | What happens |
|---|---|
| *"Show me all customers"* | Searches `res.partner` with customer filter |
| *"Create a new contact named John"* | Creates a record in `res.partner` |
| *"Update invoice #123 status"* | Writes to the specified record |
| *"Delete the test product"* | Unlinks the record (admin token required) |
| *"What models are available in Odoo?"* | Lists all accessible Odoo models |

---

## Remote Odoo Server

If your Odoo is hosted on a cloud server, just enter the full URL during setup:

```
Odoo URL: https://your-odoo-domain.com
```

Make sure your Odoo server:
- Uses **HTTPS** (required for remote access)
- Has port **443** open
- Has the `odoo_ai_agent` module installed

---

## Manual Configuration

If you prefer to edit `config.json` directly:

```json
{
  "odoo_url":   "https://your-odoo-domain.com",
  "odoo_db":    "your_database_name",
  "odoo_token": "your_token_here"
}
```

Then update `claude_desktop_config.json`:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**Linux:** `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "odoo": {
      "command": "python3",
      "args": ["/full/path/to/mcp_server/server.py"]
    }
  }
}
```

---

## Passing LLM Name (Optional)

To track which AI is making requests in Odoo's audit log, add the LLM name
to the headers in `server.py`:

```python
HEADERS = {
    'Authorization': f'Bearer {ODOO_TOKEN}',
    'Content-Type': 'application/json',
    'X-Odoo-Database': ODOO_DB,
    'X-LLM-Name': 'Claude',
}
```

This appears in **Odoo AI Agent → Request Logs**.

---

## Troubleshooting

**Hammer icon not showing in Claude Desktop**
```bash
# Check logs
cat ~/Library/Logs/Claude/mcp-server-odoo.log       # macOS
cat ~/.config/Claude/logs/mcp-server-odoo.log        # Linux
```

**Cannot connect to Odoo**
```bash
curl "http://your-odoo-url/mcp/health" \
  -H "X-Odoo-Database: your_db_name"
# Expected: {"status": "ok", "service": "RAG Odoo MCP Server", "version": "1.0.0"}
```

**Token rejected**
- Check the token is active in **Odoo AI Agent → API Tokens**
- Check the token has not expired
- Generate a new token if needed

---

## Security Tips

- Keep `config.json` out of version control — it contains your token
- Use a **read-only (user) token** for analysis tasks
- Use an **admin token** only when create/update/delete is needed
- Set an **expiry date** on tokens used by external devices
- Enable **IP whitelisting** in the Odoo configuration for extra security

---

## Support

- Maintainer: **7seven team** — 7seven.seventeam@gmail.com
- Odoo Module: `odoo_ai_agent`
