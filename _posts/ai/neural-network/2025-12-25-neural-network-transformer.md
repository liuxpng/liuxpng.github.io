---
title: Attention 与 Transformer：现代 NLP 的基石
date: 2025-12-25 10:00:00 +0800
categories: [AI, Neural Network]
tags: [Neural Network, Transformer, Attention, Self-Attention, NLP]
---

上一篇文章我们学习了 RNN 和 LSTM，它们可以处理序列数据，但有一个根本问题：必须按顺序处理，无法并行。2017 年，Google 提出了 Transformer 架构，用 **Attention 机制**完全取代了循环结构。这彻底改变了 NLP 领域，BERT、GPT 等模型都基于 Transformer。

## Attention 机制的直觉

### 从机器翻译说起

想象你在做英译中翻译：

```
英文: "The cat sat on the mat"
中文: "猫 坐 在 垫子 上"
```

翻译"猫"时，你主要看哪个英文词？

```
                  关注程度
"The"   ──────→   ■░░░░░  (低)
"cat"   ──────→   ■■■■■■  (高!) ← 这个最重要
"sat"   ──────→   ■░░░░░  (低)
"on"    ──────→   ░░░░░░  (无)
"the"   ──────→   ░░░░░░  (无)
"mat"   ──────→   ░░░░░░  (无)
```

这就是 **Attention（注意力）** 的核心思想：**在处理当前位置时，动态地关注输入的相关部分**。

### RNN 的问题

RNN 处理序列时，所有信息都压缩到一个隐藏状态向量中：

```
RNN 翻译模型：

英文: The cat sat on the mat
        ↓    ↓    ↓   ↓   ↓
      [h1]-[h2]-[h3]-[h4]-[h5]-[h6]
                              ↓
                         [压缩向量]  ← 整个句子压缩成一个向量
                              ↓
中文: 猫 坐 在 垫子 上

问题：
- 长句子信息容易丢失
- 翻译"猫"时，无法直接看到"cat"
```

### Attention 的解决方案

Attention 让解码器可以**直接查看**编码器的每个位置：

```
Attention 翻译模型：

英文: The cat sat on the mat
        ↓    ↓    ↓   ↓   ↓   ↓
      [h1] [h2] [h3] [h4] [h5] [h6]
        │    │    │   │    │    │
        └────┼────┼───┼────┼────┘
             │    │   │    │
          [Attention 权重计算]
             │
             ↓
中文:      "猫"  ← 重点关注 h2（对应"cat"）
```

---

## Attention 的计算过程

### Query、Key、Value

Attention 机制使用三个概念：

```
Query (Q): 我要找什么？（查询）
Key (K):   我有什么标签？（索引）
Value (V): 我有什么内容？（值）
```

直觉理解——图书馆找书：

```
你的问题（Query）: "我想找关于猫的书"

图书馆的书：
  书1: Key="狗", Value="狗的习性..."
  书2: Key="猫", Value="猫的习性..."  ← 匹配度最高
  书3: Key="鸟", Value="鸟的习性..."

Attention 结果: 主要返回书2的内容
```

### 计算步骤

```
步骤1: 计算匹配分数
  score = Q · K^T  (Query 和每个 Key 的点积)

步骤2: 转换为概率（Softmax）
  attention_weights = softmax(score / √d)
  其中 √d 是缩放因子，防止数值过大

步骤3: 加权求和
  output = attention_weights × V
```

### 具体例子

翻译时生成"猫"，计算对英文各词的注意力：

```
Query: "猫"的向量 = [0.2, 0.8, ...]

Keys (英文每个词):
  "The" = [0.1, 0.1, ...]
  "cat" = [0.3, 0.9, ...]  ← 和 Query 最相似
  "sat" = [0.5, 0.2, ...]
  ...

Step 1: 计算分数
  score("The") = Q · K_the = 0.1
  score("cat") = Q · K_cat = 0.9  ← 最高
  score("sat") = Q · K_sat = 0.2

Step 2: Softmax
  weights = softmax([0.1, 0.9, 0.2, ...])
          ≈ [0.05, 0.70, 0.10, ...]

Step 3: 加权求和
  output = 0.05×V_the + 0.70×V_cat + 0.10×V_sat + ...
         ≈ V_cat (主要是"cat"的信息)
```

---

## Self-Attention：句子内部的关联

### 什么是 Self-Attention

Self-Attention 是 Attention 的特殊情况：**Q、K、V 都来自同一个句子**。

```
普通 Attention (翻译):
  Q: 中文句子
  K, V: 英文句子
  → 中文关注英文的哪些部分

Self-Attention:
  Q, K, V: 都是同一个句子
  → 句子中每个词关注其他词的哪些部分
```

### 为什么需要 Self-Attention

考虑这个句子：

```
"小明把苹果给了小红，因为她饿了"

问题："她"指的是谁？
答案：小红（因为是"给"的对象）

Self-Attention 让"她"能直接关注"小红"：

小明  把  苹果  给了  小红  ，  因为  她  饿了
 │    │    │    │    ▲     │    │   │    │
 │    │    │    │    │     │    │   │    │
 └────┴────┴────┴────┼─────┴────┴───┘    │
                     │                    │
                     └────────────────────┘
                        "她" 高度关注 "小红"
```

Self-Attention 让每个词都能直接看到句子中的所有其他词。

### Self-Attention 的计算

```
输入句子: [词1, 词2, 词3, 词4]

每个词都转换为 Q, K, V:
  Q1, K1, V1 ← 词1
  Q2, K2, V2 ← 词2
  Q3, K3, V3 ← 词3
  Q4, K4, V4 ← 词4

对于词1，计算它对所有词的注意力：
  score(1→1) = Q1 · K1
  score(1→2) = Q1 · K2
  score(1→3) = Q1 · K3
  score(1→4) = Q1 · K4

  weights = softmax([score(1→1), score(1→2), ...])

  new_词1 = weights[1]×V1 + weights[2]×V2 + weights[3]×V3 + weights[4]×V4

词1的新表示融合了它关注的所有词的信息！
```

---

## Transformer 架构

2017 年论文 "Attention is All You Need" 提出的 Transformer 完全基于 Attention，没有任何循环结构。

### 整体结构

```
Transformer 架构（用于翻译）:

        输入（英文）                输出（中文）
            ↓                          ↓
    ┌───────────────┐          ┌───────────────┐
    │   Embedding   │          │   Embedding   │
    │  + 位置编码    │          │  + 位置编码    │
    └───────┬───────┘          └───────┬───────┘
            │                          │
    ┌───────▼───────┐          ┌───────▼───────┐
    │               │          │               │
    │    Encoder    │ ────────→│    Decoder    │
    │   (N层堆叠)    │          │   (N层堆叠)    │
    │               │          │               │
    └───────────────┘          └───────┬───────┘
                                       │
                                       ↓
                               ┌───────────────┐
                               │   Linear      │
                               │   + Softmax   │
                               └───────────────┘
                                       │
                                       ↓
                                    预测词
```

### Encoder 层

```
一个 Encoder 层的结构：

    输入
      │
      ▼
┌─────────────────────────────┐
│    Multi-Head Attention     │ ← Self-Attention
└─────────────┬───────────────┘
              │ + 残差连接
      ┌───────▼───────┐
      │  Layer Norm   │
      └───────┬───────┘
              │
┌─────────────▼───────────────┐
│    Feed Forward Network     │ ← 两层全连接
└─────────────┬───────────────┘
              │ + 残差连接
      ┌───────▼───────┐
      │  Layer Norm   │
      └───────┬───────┘
              │
            输出
```

### 多头注意力（Multi-Head Attention）

```
问题：一个 Attention 只能学习一种关联模式

解决：用多个 Attention "头"，学习不同的关联

            输入
              │
    ┌─────────┼─────────┐
    ↓         ↓         ↓
  Head1     Head2     Head3      (多个注意力头)
    │         │         │
    └─────────┼─────────┘
              ↓
           Concat              (拼接)
              ↓
           Linear              (线性变换)
              ↓
            输出

每个头可能学习不同的关系：
  Head1: 语法关系（主语-谓语）
  Head2: 指代关系（代词-先行词）
  Head3: 语义关系（同义词）
```

### 位置编码（Positional Encoding）

Self-Attention 没有位置信息——所有词被同等对待。但词序很重要：

```
"狗咬人" ≠ "人咬狗"

解决方案：给每个位置添加独特的编码

位置0: [sin(0), cos(0), sin(0/100), cos(0/100), ...]
位置1: [sin(1), cos(1), sin(1/100), cos(1/100), ...]
位置2: [sin(2), cos(2), sin(2/100), cos(2/100), ...]
...

最终输入 = 词向量 + 位置编码
```

---

## 为什么 Transformer 替代了 RNN

### 1. 可以并行计算

```
RNN: 必须顺序处理
  h1 → h2 → h3 → h4 → h5
  时间复杂度: O(序列长度)

Transformer: 所有位置同时计算
  词1 ─┐
  词2 ─┼─→ [Self-Attention] → 一次性得到所有输出
  词3 ─┼
  词4 ─┼
  词5 ─┘
  时间复杂度: O(1) (在 GPU 上)
```

### 2. 可以直接建模长距离依赖

```
RNN: 位置1到位置100需要经过99步传递
  信息会逐渐衰减

Transformer: 位置1可以直接关注位置100
  只需要一次 Attention 计算
  信息不会衰减
```

### 3. 更容易训练

```
RNN 的梯度需要沿时间传播：
  反向传播要经过很多步，容易梯度消失

Transformer 的梯度路径更短：
  每一层的梯度可以直接传递（通过残差连接）
  更容易训练深层网络
```

### 对比总结

| 特性 | RNN/LSTM | Transformer |
|------|----------|-------------|
| 并行计算 | 不支持 | 完全支持 |
| 长距离依赖 | 困难（需要传递） | 容易（直接关注） |
| 训练速度 | 慢 | 快 |
| 模型深度 | 通常较浅 | 可以很深 |
| 显存占用 | O(1) | O(n²)（注意力矩阵）|

---

## Transformer 的影响

### 开创了预训练时代

```
2018: BERT (Google)
  - 只用 Transformer Encoder
  - 双向预训练
  - 刷新 11 项 NLP 任务记录

2018-2023: GPT 系列 (OpenAI)
  - 只用 Transformer Decoder
  - 单向（自回归）预训练
  - GPT-4 成为通用 AI 助手

2019: T5, BART, 等等
  - 完整的 Encoder-Decoder
  - 各种预训练方式
```

### 超越 NLP

```
Transformer 被应用到几乎所有领域：

计算机视觉: ViT (Vision Transformer)
  图片分成小块 → 当作"词"处理

语音识别: Whisper
  音频特征 → Transformer 编码

蛋白质结构预测: AlphaFold
  氨基酸序列 → Transformer 预测 3D 结构

代码生成: Codex, CodeGen
  自然语言 → Transformer → 代码
```

---

## 与 Embedding 的关系

现在你能理解 BERT 是怎么工作的了：

```
BERT 的架构：

输入: "[CLS] 今天 天气 真好 [SEP]"
         ↓
      Embedding + 位置编码
         ↓
      Transformer Encoder (12层)
         ↓
      每个位置的上下文向量

"今天"的向量融合了"天气真好"的信息
"天气"的向量融合了"今天""真好"的信息
...

这就是为什么 BERT 能生成"上下文相关"的词向量！
```

这正是 [现代 Embedding 模型](/posts/embedding-modern-models/) 文章中提到的 BERT 能解决"一词多义"的原因。

---

## 总结

本文介绍了 Attention 机制和 Transformer 架构：

**Attention 机制**：
- 让模型动态关注输入的相关部分
- Query、Key、Value 三元组
- 通过点积计算匹配分数

**Self-Attention**：
- 句子内部每个词关注其他所有词
- 直接建模任意距离的依赖关系

**Transformer**：
- 完全基于 Attention，无循环结构
- 可以并行计算，训练更快
- Encoder-Decoder 结构
- 多头注意力 + 位置编码

**影响**：
- 开创了预训练语言模型时代
- BERT、GPT 等都基于 Transformer
- 扩展到视觉、语音等各个领域

至此，神经网络系列完结。你已经从感知机出发，经过多层网络、反向传播、RNN/LSTM，最终到达现代 NLP 的核心——Transformer。这些知识将帮助你更好地理解 Embedding、BERT、GPT 等技术。

---

## 延伸阅读

**神经网络系列**：

1. [神经网络起源：从生物神经元到感知机](/posts/neural-network-perceptron/) - 感知机原理与局限
2. [多层神经网络：深度学习的起点](/posts/neural-network-multilayer/) - 隐藏层与激活函数
3. [神经网络如何学习：反向传播与梯度下降](/posts/neural-network-backpropagation/) - 训练网络的核心算法
4. [序列数据的挑战：从 RNN 到 LSTM](/posts/neural-network-rnn-lstm/) - 循环神经网络
5. **本文**：Attention 与 Transformer：现代 NLP 的基石

**相关内容**：

- [现代 Embedding 模型：从 BERT 到 BGE](/posts/embedding-modern-models/) - BERT 的 Transformer 架构应用
- [理解 Embedding：为什么相似文本向量距离近](/posts/embedding-why-similar/) - 词向量原理

**经典论文**：

- 2017: Vaswani et al. - Attention Is All You Need
- 2018: Devlin et al. - BERT: Pre-training of Deep Bidirectional Transformers
- 2020: Brown et al. - Language Models are Few-Shot Learners (GPT-3)
