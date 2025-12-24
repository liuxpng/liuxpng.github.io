---
title: MCP 实战：用 OpenAI Agents SDK 快速构建 Agent
date: 2025-12-21 16:00:00 +0800
categories: [AI, MCP]
tags: [MCP, OpenAI Agents SDK, AI Agent, Python]
mermaid: true
---

手动实现 MCP Client 代码量较大。本文介绍如何使用 OpenAI Agents SDK 快速构建支持 MCP 的 Agent。

> 如果你还不了解 MCP 的基本概念，建议先阅读 [MCP 入门：AI 工具调用的统一标准](/posts/mcp-introduction/)。

## 为什么选择 OpenAI Agents SDK？

### 手动实现 vs SDK

| 方式 | 代码量 | 维护成本 | 功能完整性 |
|------|--------|----------|------------|
| 手动实现 MCP Client | ~150 行 | 高 | 需自行实现 |
| OpenAI Agents SDK | ~20 行 | 低 | 开箱即用 |

OpenAI Agents SDK 内置了 MCP 支持，自动处理：
- MCP Server 连接管理
- 工具发现与注册
- Agent 循环与工具调用

---

## 环境准备

```bash
pip install openai-agents mcp
```

---

## 快速开始

### 最简示例

```python
import asyncio
from agents import Agent, Runner
from agents.mcp import MCPServerStdio

async def main():
    # 连接 MCP Server
    weather_server = MCPServerStdio(
        command="python",
        args=["servers/weather_server.py"]
    )

    # 创建 Agent，自动发现 MCP 工具
    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手，使用可用工具回答问题。",
        mcp_servers=[weather_server]
    )

    # 运行
    async with weather_server:
        result = await Runner.run(agent, "北京今天天气怎么样？")
        print(result.final_output)

asyncio.run(main())
```

**就这么简单！** SDK 自动处理了：
1. 启动 MCP Server 进程
2. 发现可用工具
3. 将工具转换为 LLM 可用格式
4. 执行 Agent 循环

---

## 连接多个 MCP Server

```python
from agents import Agent, Runner
from agents.mcp import MCPServerStdio

async def main():
    # 定义多个 MCP Server
    weather_server = MCPServerStdio(
        command="python",
        args=["servers/weather_server.py"]
    )

    calculator_server = MCPServerStdio(
        command="python",
        args=["servers/calculator_server.py"]
    )

    # Agent 可以使用所有 Server 的工具
    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手。",
        mcp_servers=[weather_server, calculator_server]
    )

    async with weather_server, calculator_server:
        result = await Runner.run(
            agent,
            "北京和上海哪个城市更热？热多少度？"
        )
        print(result.final_output)

asyncio.run(main())
```

---

## 连接远程 MCP Server

除了 stdio 模式，还支持 HTTP+SSE 连接远程 Server：

```python
from agents.mcp import MCPServerSse

# 连接远程 MCP Server
remote_server = MCPServerSse(
    url="https://mcp.example.com/sse",
    headers={"Authorization": "Bearer your-token"}
)

agent = Agent(
    name="assistant",
    instructions="你是一个智能助手。",
    mcp_servers=[remote_server]
)
```

---

## 混合使用 MCP 工具和自定义工具

MCP 工具可以与自定义工具一起使用：

```python
from agents import Agent, Runner, function_tool
from agents.mcp import MCPServerStdio

# 自定义工具
@function_tool
def search_database(query: str) -> str:
    """搜索内部数据库"""
    return f"搜索结果：{query} 相关数据..."

async def main():
    weather_server = MCPServerStdio(
        command="python",
        args=["servers/weather_server.py"]
    )

    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手。",
        mcp_servers=[weather_server],
        tools=[search_database]  # 自定义工具
    )

    async with weather_server:
        result = await Runner.run(
            agent,
            "查询北京天气，并搜索相关旅游信息"
        )
        print(result.final_output)

asyncio.run(main())
```

---

## 获取工具调用过程

查看 Agent 的思考和工具调用过程：

```python
from agents import Agent, Runner
from agents.mcp import MCPServerStdio

async def main():
    weather_server = MCPServerStdio(
        command="python",
        args=["servers/weather_server.py"]
    )

    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手。",
        mcp_servers=[weather_server]
    )

    async with weather_server:
        result = await Runner.run(
            agent,
            "北京今天天气怎么样？"
        )

        # 查看运行过程
        for item in result.new_items:
            print(f"[{item.type}] {item}")

        print(f"\n最终答案：{result.final_output}")

asyncio.run(main())
```

输出：

```text
[tool_call] get_weather({"city": "北京"})
[tool_output] 北京：晴，25°C，湿度 40%
[message] 北京今天天气晴朗，温度 25°C，湿度 40%。

最终答案：北京今天天气晴朗，温度 25°C，湿度 40%。
```

---

## 流式输出

实时输出 Agent 响应：

```python
from agents import Agent, Runner
from agents.mcp import MCPServerStdio

async def main():
    weather_server = MCPServerStdio(
        command="python",
        args=["servers/weather_server.py"]
    )

    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手。",
        mcp_servers=[weather_server]
    )

    async with weather_server:
        result = Runner.run_streamed(
            agent,
            "详细介绍北京的天气情况"
        )

        async for event in result.stream_events():
            if event.type == "raw_response_event":
                print(event.data, end="", flush=True)

asyncio.run(main())
```

---

## 对比：手动实现 vs SDK

### 手动实现（约 150 行）

```python
# 需要自己实现：
# - MCPClient 类
# - 连接管理
# - 工具发现
# - 工具调用
# - Schema 转换
# - Agent 循环
# - 错误处理
# ...
```

详见 [MCP 与 Agent 集成](/posts/mcp-agent-integration/)。

### 使用 SDK（约 20 行）

```python
from agents import Agent, Runner
from agents.mcp import MCPServerStdio

async def main():
    server = MCPServerStdio(command="python", args=["server.py"])

    agent = Agent(
        name="assistant",
        instructions="你是一个智能助手。",
        mcp_servers=[server]
    )

    async with server:
        result = await Runner.run(agent, "你的问题")
        print(result.final_output)

asyncio.run(main())
```

**结论**：使用 SDK 可以专注于业务逻辑，而非协议实现。

---

## 总结

| 功能 | 实现方式 |
|------|----------|
| 连接 MCP Server | `MCPServerStdio` / `MCPServerSse` |
| 创建 Agent | `Agent(mcp_servers=[...])` |
| 运行 Agent | `Runner.run(agent, prompt)` |
| 混合工具 | `tools=[...] + mcp_servers=[...]` |
| 流式输出 | `Runner.run_streamed()` |

---

## 延伸阅读

**MCP 系列**：

1. [MCP 入门：AI 工具调用的统一标准](/posts/mcp-introduction/) - 基础概念
2. [MCP 实战：用 Python 开发你的第一个 MCP Server](/posts/mcp-server-development/) - Server 开发
3. [MCP 与 Agent 集成：让 Agent 动态发现和调用工具](/posts/mcp-agent-integration/) - 手动实现
4. **本文**：MCP 实战：用 OpenAI Agents SDK 快速构建 Agent

**官方资源**：

- [OpenAI Agents SDK](https://github.com/openai/openai-agents-python)
- [MCP 官方文档](https://modelcontextprotocol.io/)
