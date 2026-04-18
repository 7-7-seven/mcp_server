#!/usr/bin/env python3
"""
Odoo MCP stdio server.

Runs as a standalone process (not inside Odoo). Claude Desktop launches it via
stdio transport. It translates MCP tool calls into HTTP requests to the Odoo
REST controller at /mcp/sse.
"""

import asyncio
import json
import logging
import os
import sys
import requests
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent, CallToolResult

# ------------------------------------------------------------------ config

_HERE = os.path.dirname(os.path.abspath(__file__))
_CONFIG_PATH = os.path.join(_HERE, 'config.json')

if not os.path.exists(_CONFIG_PATH):
    sys.stderr.write(
        f'[odoo-mcp] ERROR: config.json not found at {_CONFIG_PATH}\n'
        f'[odoo-mcp] Run setup.sh first to configure the server.\n'
    )
    sys.exit(1)

with open(_CONFIG_PATH) as _f:
    _cfg = json.load(_f)

ODOO_URL   = _cfg.get('odoo_url',   'http://localhost:8069')
ODOO_DB    = _cfg.get('odoo_db',    '')
ODOO_TOKEN = _cfg.get('odoo_token', '')

HEADERS = {
    'Authorization': f'Bearer {ODOO_TOKEN}',
    'Content-Type': 'application/json',
    'X-Odoo-Database': ODOO_DB,
}

logging.basicConfig(stream=sys.stderr, level=logging.INFO,
                    format='[odoo-mcp] %(levelname)s %(message)s')
log = logging.getLogger(__name__)

# ------------------------------------------------------------------ helpers

def call_odoo(action: str, **params) -> dict:
    """POST to /mcp/sse and return the parsed JSON response."""
    payload = {'action': action, **params}
    resp = requests.post(f'{ODOO_URL}/mcp/sse', json=payload, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return resp.json()


def ok(data: dict) -> CallToolResult:
    return CallToolResult(content=[TextContent(type='text', text=json.dumps(data, indent=2, default=str))])


def err(message: str) -> CallToolResult:
    return CallToolResult(content=[TextContent(type='text', text=f'Error: {message}')], isError=True)


# ------------------------------------------------------------------ tools

TOOLS = [
    Tool(
        name='odoo_search',
        description='Search records in any Odoo model using domain filters.',
        inputSchema={
            'type': 'object',
            'properties': {
                'model':  {'type': 'string', 'description': 'Odoo model technical name, e.g. res.partner'},
                'domain': {'type': 'array',  'description': 'Odoo domain filter, e.g. [["customer_rank",">",0]]', 'default': []},
                'fields': {'type': 'array',  'description': 'Field names to return. Empty = all fields.', 'default': []},
                'limit':  {'type': 'integer','description': 'Maximum number of records to return.', 'default': 10},
                'offset': {'type': 'integer','description': 'Number of records to skip.', 'default': 0},
                'order':  {'type': 'string', 'description': 'Sort order, e.g. "name asc"', 'default': ''},
            },
            'required': ['model'],
        },
    ),
    Tool(
        name='odoo_read',
        description='Read specific Odoo records by their IDs.',
        inputSchema={
            'type': 'object',
            'properties': {
                'model':  {'type': 'string'},
                'ids':    {'type': 'array', 'items': {'type': 'integer'}, 'description': 'List of record IDs'},
                'fields': {'type': 'array', 'description': 'Field names to return. Empty = all.', 'default': []},
            },
            'required': ['model', 'ids'],
        },
    ),
    Tool(
        name='odoo_create',
        description='Create a new record in an Odoo model. Requires admin token.',
        inputSchema={
            'type': 'object',
            'properties': {
                'model':  {'type': 'string'},
                'values': {'type': 'object', 'description': 'Field values for the new record'},
            },
            'required': ['model', 'values'],
        },
    ),
    Tool(
        name='odoo_write',
        description='Update existing Odoo records by ID. Requires admin token.',
        inputSchema={
            'type': 'object',
            'properties': {
                'model':  {'type': 'string'},
                'ids':    {'type': 'array', 'items': {'type': 'integer'}},
                'values': {'type': 'object', 'description': 'Field values to update'},
            },
            'required': ['model', 'ids', 'values'],
        },
    ),
    Tool(
        name='odoo_unlink',
        description='Delete Odoo records by ID. Requires admin token.',
        inputSchema={
            'type': 'object',
            'properties': {
                'model': {'type': 'string'},
                'ids':   {'type': 'array', 'items': {'type': 'integer'}},
            },
            'required': ['model', 'ids'],
        },
    ),
    Tool(
        name='odoo_list_models',
        description='List all available Odoo models with their technical names.',
        inputSchema={
            'type': 'object',
            'properties': {},
        },
    ),
]

# ------------------------------------------------------------------ server

app = Server('odoo-mcp')


@app.list_tools()
async def list_tools() -> list[Tool]:
    return TOOLS


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> CallToolResult:
    log.info('tool=%s args=%s', name, arguments)
    try:
        if name == 'odoo_search':
            result = call_odoo(
                'search',
                model=arguments['model'],
                domain=arguments.get('domain', []),
                fields=arguments.get('fields', []),
                limit=arguments.get('limit', 10),
                offset=arguments.get('offset', 0),
                order=arguments.get('order', ''),
            )

        elif name == 'odoo_read':
            result = call_odoo(
                'read',
                model=arguments['model'],
                ids=arguments['ids'],
                fields=arguments.get('fields', []),
            )

        elif name == 'odoo_create':
            result = call_odoo(
                'create',
                model=arguments['model'],
                values=arguments['values'],
            )

        elif name == 'odoo_write':
            result = call_odoo(
                'write',
                model=arguments['model'],
                ids=arguments['ids'],
                values=arguments['values'],
            )

        elif name == 'odoo_unlink':
            result = call_odoo(
                'unlink',
                model=arguments['model'],
                ids=arguments['ids'],
            )

        elif name == 'odoo_list_models':
            result = call_odoo('list_models')

        else:
            return err(f"Unknown tool: {name}")

        return ok(result)

    except requests.exceptions.ConnectionError:
        return err(f"Cannot connect to Odoo at {ODOO_URL}. Is Odoo running?")
    except requests.exceptions.HTTPError as e:
        return err(f"Odoo HTTP error: {e.response.status_code} — {e.response.text}")
    except Exception as e:
        log.exception('Unexpected error in tool %s', name)
        return err(str(e))


# ------------------------------------------------------------------ main

async def main():
    log.info('Odoo MCP server starting (db=%s url=%s)', ODOO_DB, ODOO_URL)
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == '__main__':
    asyncio.run(main())
