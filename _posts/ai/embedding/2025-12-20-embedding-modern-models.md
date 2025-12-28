---
title: 现代 Embedding 模型：从 BERT 到 BGE
date: 2025-12-20 12:00:00 +0800
categories: [AI, Embedding]
tags: [Embedding, BERT, Sentence-BERT, BGE, 模型选型]
---

上一篇文章我们了解了 Word2Vec 的原理和局限：一词一向量，无法处理一词多义。本文将介绍现代 Embedding 模型如何解决这个问题，以及如何选择适合你的模型。

## BERT：上下文相关的 Embedding

### Word2Vec 的问题回顾

Word2Vec 给每个词一个固定的向量：

```
"苹果" → [0.12, -0.34, 0.56, ...]  （永远是这个向量）
```

无论"苹果"出现在什么句子中，向量都一样。这导致：

```
"苹果很好吃"      → "苹果"向量 = 水果+公司的混合体
"苹果发布新手机"  → "苹果"向量 = 水果+公司的混合体（同样的向量）
```

### BERT 的解决方案

**BERT（Bidirectional Encoder Representations from Transformers）** 是 Google 在 2018 年发布的模型。它的核心创新是：

> 词的向量由**整个句子**决定，而不是词本身。

```
"苹果很好吃"      → "苹果"向量 = 偏向水果的向量
"苹果发布新手机"  → "苹果"向量 = 偏向公司的向量
```

同一个词，在不同句子中会有不同的向量！

### BERT 是怎么做到的

BERT 使用 **Transformer** 架构，处理流程如下：

```
输入句子："苹果 很 好吃"

第1步：分词
        ["苹果", "很", "好吃"]

第2步：每个词先获得一个初始向量（类似 Word2Vec）

第3步：通过 Transformer 层，每个词"看到"其他所有词

第4步：输出的向量已经融合了上下文信息

        "苹果"的向量 ← 受到"很"和"好吃"的影响
                      → 偏向"水果"的语义
```

关键在第3步：Transformer 让每个词都能"看到"句子中的其他词，从而根据上下文调整自己的向量。

### BERT 向量的特点

| 特性 | Word2Vec | BERT |
|------|----------|------|
| 向量生成 | 词 → 向量 | 词 + 上下文 → 向量 |
| 一词多义 | 不支持 | 支持 |
| 计算成本 | 低（查表） | 高（需要跑模型） |
| 向量维度 | 100-300 | 768-1024 |

### BERT 做句子 Embedding 的问题

虽然 BERT 能生成很好的词向量，但直接用于**句子相似度**效果不佳。

常见做法是取 BERT 的 `[CLS]` token 向量作为句子向量：

```
输入："[CLS] 今天 天气 真好 [SEP]"
输出：取 [CLS] 对应的向量作为整个句子的表示
```

但实验表明，这种方法效果很差，甚至不如简单地平均所有词的向量。

原因是：BERT 的预训练目标（遮盖词预测）并没有专门优化句子级别的语义相似度。

---

## Sentence-BERT：专门优化句子相似度

### 问题：BERT 计算太慢

假设你想找出 10000 个句子中与查询最相似的，用原始 BERT：

```
查询句子 与 句子1 → 拼接 → 过 BERT → 得分
查询句子 与 句子2 → 拼接 → 过 BERT → 得分
...
查询句子 与 句子10000 → 拼接 → 过 BERT → 得分

需要跑 BERT 10000 次！
```

这太慢了，根本无法用于实际检索。

### Sentence-BERT 的方案

**Sentence-BERT（SBERT）** 在 2019 年提出，解决了两个问题：

1. 让每个句子有一个独立的向量（不需要拼接）
2. 让这个向量真正反映句子的语义

**核心思想**：用**孪生网络**训练

```
        句子A              句子B
          ↓                  ↓
        BERT               BERT（共享参数）
          ↓                  ↓
        向量A              向量B
          ↓                  ↓
        计算相似度 ←→ 与真实标签对比
```

训练数据是成对的句子，标注了它们是否相似。模型学习让：
- 相似句子的向量距离近
- 不相似句子的向量距离远

### 使用 Sentence-BERT

训练好后，使用非常简单：

```
句子 → BERT → 向量（768维）
```

每个句子独立得到一个向量，可以提前计算好存起来。检索时：

```
查询向量 与 所有预计算的向量 → 计算距离 → 找最近的
```

只需要计算向量距离，不需要再跑 BERT，速度提升几个数量级。

---

## 对比学习：让 Embedding 更强

### 什么是对比学习

**对比学习（Contrastive Learning）** 是一种训练方法：

> 拉近相似样本，推远不相似样本

```
正样本对（应该相似）：
  "今天天气真好" ↔ "今天阳光明媚"

负样本对（应该不相似）：
  "今天天气真好" ↔ "股票大跌了"
```

训练目标：

```
相似度(正样本对) > 相似度(负样本对)
```

### SimCSE：简单高效的对比学习

**SimCSE** 在 2021 年提出了一个巧妙的想法：**用 Dropout 构造正样本**

```
原句子："今天天气真好"
        ↓
    过 BERT（Dropout=0.1）
        ↓
    向量A

同一个句子再过一次：
原句子："今天天气真好"
        ↓
    过 BERT（Dropout=0.1，但随机丢弃的神经元不同）
        ↓
    向量B

向量A 和 向量B 应该相似（因为是同一个句子）
向量A 和 其他句子的向量 应该不相似
```

这种方法不需要人工标注的相似句子对，就能训练出很好的句子 Embedding。

---

## 检索专用模型：BGE、E5、GTE

### 为什么需要专用模型

Sentence-BERT 和 SimCSE 改进了句子相似度，但它们主要针对语义相似任务。

实际的**检索场景**有其特殊性：

```
查询（Query）："如何退货"（短，问题形式）
文档（Document）："退货流程：1. 进入订单页面 2. 点击退货按钮..."（长，陈述形式）
```

查询和文档的形式差异很大，需要专门优化。

### BGE：智源研究院的模型

**BGE（BAAI General Embedding）** 是智源研究院开发的 Embedding 模型：

**特点**：
- 专门针对中文优化
- 支持多种任务（检索、分类、聚类）
- 使用大规模数据训练

**使用方式**：

```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('BAAI/bge-large-zh-v1.5')

# 编码查询（加 query 前缀提升效果）
query_embedding = model.encode("为了获得更准确的结果，请问如何退货")

# 编码文档
doc_embedding = model.encode("退货流程：1. 进入订单页面...")
```

### E5：微软的模型

**E5（EmbEddings from bidirEctional Encoder rEpresentations）** 是微软开发的模型：

**特点**：
- 支持多语言
- **指令感知**：可以告诉模型你想做什么任务

**使用方式**：

```python
# 查询加 "query: " 前缀
query = "query: 如何退货"

# 文档加 "passage: " 前缀
doc = "passage: 退货流程：1. 进入订单页面..."
```

### 模型对比

| 模型 | 来源 | 中文支持 | 特点 |
|------|------|---------|------|
| BGE | 智源研究院 | 优秀 | 中文场景首选 |
| E5 | 微软 | 良好 | 多语言，指令感知 |
| GTE | 阿里巴巴 | 良好 | 高性能 |
| text-embedding-3 | OpenAI | 良好 | 易用，商业API |

---

## 如何选择 Embedding 模型

### 选择考虑因素

| 因素 | 说明 |
|------|------|
| **语言** | 中文场景优先 BGE；多语言选 E5 或 OpenAI |
| **部署方式** | 开源模型需要 GPU；API 模型无需部署 |
| **成本** | 开源免费但需硬件；API 按调用计费 |
| **性能要求** | 参考 MTEB 排行榜评估 |

### 推荐路径

**快速验证 / 原型开发**：
- 使用 OpenAI text-embedding-3-small
- 简单易用，效果稳定

**生产环境（中文）**：
- 使用 BGE-large-zh
- 开源免费，效果出色

**生产环境（多语言）**：
- 使用 BGE-M3 或 E5-large
- 都支持多语言

### MTEB 排行榜

选择模型时，可以参考 **MTEB（Massive Text Embedding Benchmark）** 排行榜：

[https://huggingface.co/spaces/mteb/leaderboard](https://huggingface.co/spaces/mteb/leaderboard)

MTEB 评估模型在多种任务上的表现：
- 检索（Retrieval）
- 语义相似度（STS）
- 分类（Classification）
- 聚类（Clustering）

根据你的具体场景，选择对应任务上表现最好的模型。

---

## Embedding 技术的演进总结

```
2013  Word2Vec     一词一向量，开创先河
        ↓
2018  BERT        上下文相关向量，解决一词多义
        ↓
2019  Sentence-BERT  优化句子相似度
        ↓
2021  SimCSE      对比学习，无需标注数据
        ↓
2023  BGE/E5/GTE   检索专用，大规模训练
```

每一步都在解决前一步的问题：
- Word2Vec → 无法处理一词多义 → BERT
- BERT → 句子相似度差 → Sentence-BERT
- Sentence-BERT → 检索场景不够优化 → BGE/E5

---

## 总结

本文介绍了现代 Embedding 模型的发展：

**BERT**：
- 上下文相关的向量，解决一词多义
- 但直接用于句子相似度效果不好

**Sentence-BERT**：
- 孪生网络优化句子相似度
- 每个句子独立得到向量，可预计算

**对比学习**：
- SimCSE 等方法进一步提升效果
- 不需要人工标注的相似句子对

**检索专用模型**：
- BGE、E5、GTE 专门针对检索优化
- 中文场景推荐 BGE

**模型选择**：
- 快速验证：OpenAI API
- 中文生产：BGE-large-zh
- 多语言：BGE-M3 或 E5

---

## 延伸阅读

**Embedding 系列**：

1. [文本向量化入门：从词袋到 TF-IDF](/posts/embedding-text-vectorization/) - 稀疏向量基础
2. [理解 Embedding：为什么相似文本向量距离近](/posts/embedding-why-similar/) - 密集向量原理
3. **本文**：现代 Embedding 模型：从 BERT 到 BGE

**神经网络基础**（理解 BERT 的 Transformer 架构）：

- [Attention 与 Transformer：现代 NLP 的基石](/posts/neural-network-transformer/) - BERT 的架构基础
- [神经网络系列完整目录](/posts/neural-network-perceptron/) - 从感知机到 Transformer

**相关技术**：

- [RAG 核心组件：Embedding 与向量数据库](/posts/rag-embedding-vector-database/) - RAG 中的 Embedding 应用

**经典论文**：

- [BERT](https://arxiv.org/abs/1810.04805) - Pre-training of Deep Bidirectional Transformers
- [Sentence-BERT](https://arxiv.org/abs/1908.10084) - Sentence Embeddings using Siamese BERT-Networks
- [SimCSE](https://arxiv.org/abs/2104.08821) - Simple Contrastive Learning of Sentence Embeddings
