---
title: MCP 实战：用 Python 开发你的第一个 MCP Server
date: 2025-12-21 14:00:00 +0800
categories: [AI, MCP]
tags: [MCP, Python, MCP Server, 工具开发]
mermaid: true
---

本文将手把手带你使用 Python 官方 SDK 开发一个 MCP Server，并接入 Claude Desktop 进行测试。

> 如果你还不了解 MCP 的基本概念，建议先阅读 [MCP 入门：AI 工具调用的统一标准](/posts/mcp-introduction/)。

## 环境准备

### SDK 选择

| SDK | 特点 | 安装 |
|-----|------|------|
| **mcp** (官方) | 参考实现，严格遵循协议 | `pip install mcp` |
| **FastMCP** | 更简洁的 API，自动类型推断 | `pip install fastmcp` |

本文使用官方 SDK。FastMCP 示例见文末。

### 安装

```bash
mkdir my-mcp-server && cd my-mcp-server
python -m venv venv && source venv/bin/activate
pip install mcp
```

### 项目结构

```
my-mcp-server/
├── venv/
├── server.py          # MCP Server 主文件
├── requirements.txt   # 依赖
└── README.md
```

---

## 第一个 MCP Server：天气查询

### 完整代码

```python
# server.py
import asyncio
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    Tool,
    TextContent,
    CallToolResult
)

# 创建 Server 实例
server = Server("weather-server")


# 定义工具列表
@server.list_tools()
async def list_tools() -> list[Tool]:
    """返回可用工具列表"""
    return [
        Tool(
            name="get_weather",
            description="获取指定城市的当前天气信息",
            inputSchema={
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "城市名称，如：北京、上海"
                    }
                },
                "required": ["city"]
            }
        )
    ]


# 处理工具调用
@server.call_tool()
async def call_tool(name: str, arguments: dict) -> CallToolResult:
    """处理工具调用请求"""
    if name == "get_weather":
        city = arguments.get("city", "未知")

        # 模拟天气数据（实际应用中调用真实 API）
        weather_data = {
            "北京": {"condition": "晴", "temp": 25, "humidity": 40},
            "上海": {"condition": "多云", "temp": 28, "humidity": 65},
            "广州": {"condition": "雷阵雨", "temp": 30, "humidity": 80},
            "深圳": {"condition": "晴", "temp": 29, "humidity": 70},
        }

        if city in weather_data:
            data = weather_data[city]
            result = f"{city}：{data['condition']}，温度 {data['temp']}°C，湿度 {data['humidity']}%"
        else:
            result = f"抱歉，暂无 {city} 的天气数据"

        return CallToolResult(
            content=[TextContent(type="text", text=result)]
        )

    return CallToolResult(
        content=[TextContent(type="text", text=f"未知工具：{name}")]
    )


# 主函数
async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
```

### 运行测试

```bash
# stdio 模式的 Server 需要由 Host 应用（如 Claude Desktop）启动
# 直接运行会因 stdin 无输入而立即退出，这是正常行为
python server.py
```

---

## 添加更多工具

扩展 Server，添加多个工具：

```python
# server.py - 多工具版本
import asyncio
from datetime import datetime
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent, CallToolResult

server = Server("multi-tool-server")


@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="get_weather",
            description="获取城市天气",
            inputSchema={
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "城市名称"}
                },
                "required": ["city"]
            }
        ),
        Tool(
            name="get_time",
            description="获取当前时间",
            inputSchema={"type": "object", "properties": {}}
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> CallToolResult:
    if name == "get_weather":
        city = arguments.get("city", "未知")
        data = {"北京": "晴，25°C", "上海": "多云，28°C"}
        result = data.get(city, f"暂无 {city} 的天气数据")
    elif name == "get_time":
        result = f"当前时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    else:
        result = f"未知工具：{name}"

    return CallToolResult(content=[TextContent(type="text", text=result)])


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
```

---

## 添加资源（Resources）

MCP Server 可以暴露资源供 LLM 读取：

```python
from mcp.types import Resource, ReadResourceResult, TextResourceContents

documents = {
    "readme": {"title": "项目说明", "content": "这是一个示例项目..."},
    "api": {"title": "API 文档", "content": "接口说明..."},
}


@server.list_resources()
async def list_resources() -> list[Resource]:
    return [
        Resource(uri=f"doc://{id}", name=doc["title"], mimeType="text/plain")
        for id, doc in documents.items()
    ]


@server.read_resource()
async def read_resource(uri: str) -> ReadResourceResult:
    doc_id = uri.replace("doc://", "")
    if doc_id in documents:
        doc = documents[doc_id]
        return ReadResourceResult(contents=[
            TextResourceContents(uri=uri, mimeType="text/plain", text=doc["content"])
        ])
    raise ValueError(f"资源不存在：{uri}")
```

---

## 添加提示词模板（Prompts）

预定义的提示词模板：

```python
from mcp.types import Prompt, PromptArgument, GetPromptResult, PromptMessage, TextContent


@server.list_prompts()
async def list_prompts() -> list[Prompt]:
    return [
        Prompt(
            name="summarize",
            description="文本摘要",
            arguments=[PromptArgument(name="text", description="要总结的文本", required=True)]
        ),
        Prompt(
            name="translate",
            description="翻译文本",
            arguments=[PromptArgument(name="text", description="要翻译的文本", required=True)]
        )
    ]


@server.get_prompt()
async def get_prompt(name: str, arguments: dict) -> GetPromptResult:
    text = arguments.get("text", "")

    if name == "summarize":
        prompt = f"请将以下文本总结为简短摘要：\n\n{text}"
    elif name == "translate":
        prompt = f"请将以下文本翻译成英文：\n\n{text}"
    else:
        raise ValueError(f"未知提示词：{name}")

    return GetPromptResult(messages=[
        PromptMessage(role="user", content=TextContent(type="text", text=prompt))
    ])
```

---

## 错误处理

通过 `isError=True` 标记错误：

```python
@server.call_tool()
async def call_tool(name: str, arguments: dict) -> CallToolResult:
    try:
        # 业务逻辑...
        return CallToolResult(content=[TextContent(type="text", text=result)])
    except Exception as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"错误：{e}")],
            isError=True
        )
```

---

## 调用真实 API

将模拟数据替换为真实 API 调用：

```python
import httpx

async def get_weather_real(city: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://api.weatherapi.com/v1/current.json",
            params={"key": "your-api-key", "q": city}
        )
        data = resp.json()
        return f"{city}：{data['current']['condition']['text']}，{data['current']['temp_c']}°C"
```

---

## 项目结构

```
my-mcp-server/
├── server.py          # MCP Server 主文件
├── requirements.txt   # mcp>=1.0.0, httpx>=0.25.0
└── venv/
```

---

## 附：FastMCP 写法

[FastMCP](https://github.com/jlowin/fastmcp) 提供更简洁的 API，自动从函数签名生成 Schema：

```python
from fastmcp import FastMCP

mcp = FastMCP("weather-server")


@mcp.tool
def get_weather(city: str) -> str:
    """获取城市天气"""
    data = {"北京": "晴，25°C", "上海": "多云，28°C"}
    return data.get(city, f"暂无 {city} 的天气数据")


@mcp.resource("doc://readme")
def get_readme() -> str:
    """项目说明文档"""
    return "这是一个示例项目..."


if __name__ == "__main__":
    mcp.run()
```

**对比**：官方 SDK 需要手写 `inputSchema`，FastMCP 从类型提示自动推断。

---

## 总结

本文介绍了如何用 Python 开发 MCP Server：

| 步骤 | 内容 |
|------|------|
| 环境准备 | 安装 `mcp` 包 |
| 定义工具 | `@server.list_tools()` + `@server.call_tool()` |
| 添加资源 | `@server.list_resources()` + `@server.read_resource()` |
| 添加提示词 | `@server.list_prompts()` + `@server.get_prompt()` |

---

## 延伸阅读

**MCP 系列**：

1. [MCP 入门：AI 工具调用的统一标准](/posts/mcp-introduction/) - 基础概念
2. **本文**：MCP 实战：用 Python 开发你的第一个 MCP Server
3. [MCP 与 Agent 集成：让 Agent 动态发现和调用工具](/posts/mcp-agent-integration/) - 手动实现
4. [MCP 实战：用 OpenAI Agents SDK 快速构建 Agent](/posts/mcp-openai-agents-sdk/) - SDK 集成

> 开发完成后，参考 [MCP 官方文档](https://modelcontextprotocol.io/quickstart) 配置 Claude Desktop 或 IDE 集成。

**官方资源**：

- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [FastMCP](https://github.com/jlowin/fastmcp) - 社区流行的简化框架
- [MCP 官方文档](https://modelcontextprotocol.io/)
