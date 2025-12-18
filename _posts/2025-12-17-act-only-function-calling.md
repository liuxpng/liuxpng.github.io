---
title: Act-only 模式：让 AI 调用工具
date: 2025-12-17 13:00:00 +0800
categories: [AI, Agent]
tags: [Function Calling, Tool Use, LLM, AI Agent]
---

"帮我查一下今天北京的天气"——面对这类请求，纯粹的语言模型无能为力。它只能生成文本，无法真正获取实时信息。

**Act-only 模式**（也称 Function Calling 或 Tool Use）正是为了让 LLM 能够"行动"而生。

## 什么是 Act-only 模式？

Act-only 模式让 LLM 能够调用外部工具来完成任务。模型不再只是生成文本，而是输出结构化的"行动指令"，由系统执行后返回结果。

```text
用户：今天北京天气怎么样？

模型输出：
{
  "action": "get_weather",
  "parameters": { "city": "北京" }
}

系统执行 get_weather("北京")，返回：
"北京今天晴，气温 -2°C 到 8°C"

模型最终回答：
北京今天天气晴朗，气温在 -2°C 到 8°C 之间，建议注意保暖。
```

## 工作流程

Act-only 模式的典型流程：

1. **接收请求**：用户提出问题或任务
2. **选择工具**：模型判断需要调用什么工具
3. **生成参数**：模型输出工具名称和参数
4. **执行调用**：系统执行工具，获取结果
5. **生成回复**：模型基于结果生成最终回答

## 实现方式

### OpenAI Function Calling

OpenAI 在 2023 年推出了原生的 Function Calling 支持：

```python
tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "获取指定城市的天气",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "城市名称"}
            },
            "required": ["city"]
        }
    }
}]

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "北京天气如何？"}],
    tools=tools
)
```

模型会自动识别何时需要调用工具，并输出结构化的调用请求。

### 纯 Prompt 实现

在没有原生支持的情况下，也可以通过 Prompt 实现：

```text
你可以使用以下工具：
- get_weather(city): 获取城市天气
- search(query): 搜索信息

当需要使用工具时，按以下格式输出：
Action: 工具名称
Action Input: 参数

用户问题：北京天气如何？
```

## 局限性

Act-only 模式解决了"行动"的问题，但带来了新的局限：

**1. 缺乏规划**

模型直接选择工具，没有思考"为什么要用这个工具"、"用完之后下一步是什么"。

**2. 缺乏反思**

执行失败或结果不理想时，模型不会主动调整策略，只是机械地重试或放弃。

**3. 难以处理多步任务**

对于需要多次工具调用、前后依赖的复杂任务，Act-only 模式表现不佳。

例如，"苹果公司 CEO 的母校在哪个城市？"这个问题需要：
1. 先查 CEO 是谁
2. 再查他的母校
3. 最后查学校位置

Act-only 模式难以自主完成这种链式推理。

## 与 ReAct 的关系

[ReAct 模式](/posts/react-agent-introduction/)正是为了解决 Act-only 的局限而提出的。它在每次行动前加入"思考"步骤：

| 模式 | 流程 |
|------|------|
| Act-only | Action → Observation → Action → ... |
| ReAct | **Thought** → Action → Observation → **Thought** → Action → ... |

通过让推理指导行动、行动支撑推理，ReAct 实现了更智能的任务处理。

## 总结

Act-only 模式是 AI Agent 的重要基础：

- **核心**：让 LLM 能够调用外部工具
- **实现**：原生 Function Calling 或 Prompt 工程
- **价值**：突破了纯文本生成的局限
- **不足**：缺乏规划和反思能力

它解决了"如何行动"的问题，但要真正完成复杂任务，还需要与推理能力结合——这正是 [ReAct](/posts/react-agent-introduction/) 的核心贡献。

---

> **延伸阅读**
> - [ReAct 模式入门：让 AI 学会思考与行动](/posts/react-agent-introduction/)
> - [Chain-of-Thought：让 AI 学会"一步步思考"](/posts/chain-of-thought-introduction/)
