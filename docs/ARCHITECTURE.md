# Architecture Documentation

Complete technical architecture of the n8n Lead Generation Automation system.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Layer 1: High-Level Architecture](#layer-1-high-level-architecture)
3. [Layer 2: Component Architecture](#layer-2-component-architecture)
4. [Layer 3: Data Flow](#layer-3-data-flow)
5. [Layer 4: Detailed Node-by-Node Flow](#layer-4-detailed-node-by-node-flow)
6. [Data Schema](#data-schema)
7. [Scoring Algorithm](#scoring-algorithm)
8. [Failure Handling](#failure-handling)

---

## System Overview

```mermaid
mindmap
  root((Lead Gen<br/>Automation))
    Inputs
      Schedule Trigger
      Webhook Events
      Manual Runs
    Data Sources
      Company APIs
      Apollo.io
      Clearbit
    Processing
      Data Transform
      Rule-Based Scoring
      AI Analysis - Claude
      Deduplication
    Storage
      Google Sheets
    Outputs
      Slack Alerts
      Email Reports
      Webhook Response
```

**Core concept:** Three independent but connected workflows that together automate the entire lead lifecycle from discovery to qualified handoff.

---

## Layer 1: High-Level Architecture

This is the 30,000-foot view — how the major pieces fit together.

```mermaid
flowchart TB
    subgraph External["External World"]
        API1[Company Data APIs]
        API2[Apollo.io]
        API3[Clearbit]
        AI[Claude AI]
    end

    subgraph Platform["n8n Automation Platform (Docker)"]
        WF1[Workflow 1<br/>Lead Scraper]
        WF2[Workflow 2<br/>Lead Enrichment]
        WF3[Workflow 3<br/>Notification Hub]
    end

    subgraph Storage["Data Layer"]
        GS[(Google Sheets<br/>Lead Database)]
    end

    subgraph Users["End Users"]
        Sales[Sales Team]
        Slack[Slack Channels]
        Email[Email Inbox]
    end

    API1 -->|Daily pull| WF1
    WF1 -->|Store leads| GS
    WF1 -->|New lead event| WF2
    WF2 <-->|Enrich| API2
    WF2 <-->|Enrich| API3
    WF2 <-->|Analyze| AI
    WF2 -->|Update| GS
    WF1 -->|Event| WF3
    WF2 -->|Event| WF3
    WF3 -->|Push alerts| Slack
    WF3 -->|Send digest| Email
    Sales -->|Read & act| GS
    Slack -->|Notify| Sales
    Email -->|Notify| Sales

    style WF1 fill:#FF6D5A,color:#fff
    style WF2 fill:#CC785C,color:#fff
    style WF3 fill:#4A154B,color:#fff
    style GS fill:#34A853,color:#fff
    style AI fill:#D4A27F,color:#000
```

### Key Design Principles

| Principle | How It's Implemented |
|-----------|---------------------|
| **Separation of Concerns** | 3 separate workflows — each does one thing well |
| **Event-Driven** | Workflows trigger each other via webhooks |
| **Idempotent** | Deduplication prevents duplicate entries |
| **Observable** | Every run logs summary stats + notifications |
| **Fail-Safe** | One API failure doesn't stop the pipeline |

---

## Layer 2: Component Architecture

Zooming in on each workflow and what it contains.

```mermaid
flowchart LR
    subgraph WF1["🔍 Workflow 1: Lead Scraper"]
        direction TB
        T1[Schedule Trigger<br/>Cron: 0 9 * * 1-5]
        H1[HTTP Request<br/>Fetch Companies]
        C1[Code Node<br/>Transform + Score]
        D1[Remove Duplicates<br/>by name + domain]
        S1[Google Sheets<br/>Append or Update]
        I1{IF Condition<br/>quality tier = hot?}
        N1a[Slack Node]
        N1b[Email Node]
        Sum1[Code: Run Summary]

        T1 --> H1 --> C1 --> D1 --> S1
        S1 --> I1
        S1 --> Sum1
        I1 -->|yes| N1a
        I1 -->|yes| N1b
    end
```

```mermaid
flowchart LR
    subgraph WF2["🤖 Workflow 2: Lead Enrichment"]
        direction TB
        T2[Webhook Trigger<br/>POST /enrich-lead]
        H2a[HTTP: Apollo API<br/>Find contacts]
        H2b[HTTP: Clearbit API<br/>Company intel]
        M2[Code: Merge Data<br/>Combine sources]
        AI2[HTTP: Claude API<br/>AI Analysis]
        F2[Code: Final Score<br/>Weighted calc]
        U2[Google Sheets<br/>Update row]
        I2{IF: High priority?}
        N2[Slack: Urgent]
        R2[Respond to Webhook]

        T2 --> H2a
        T2 --> H2b
        H2a --> M2
        H2b --> M2
        M2 --> AI2 --> F2 --> U2 --> I2
        I2 -->|yes| N2
        I2 --> R2
        N2 --> R2
    end
```

```mermaid
flowchart LR
    subgraph WF3["📢 Workflow 3: Notification Hub"]
        direction TB
        T3[Webhook Trigger<br/>POST /lead-notification]
        SW[Switch Node<br/>Route by event_type]
        N3a[Slack: New Lead<br/>#leads-new]
        N3b[Slack: Scored<br/>#leads-scored]
        N3c[Email: Daily Summary<br/>sales-team@]
        R3[Build Response]

        T3 --> SW
        SW -->|new_lead| N3a --> R3
        SW -->|lead_scored| N3b --> R3
        SW -->|daily_summary| N3c --> R3
    end
```

---

## Layer 3: Data Flow

How a single lead moves through the entire system from discovery to qualified handoff.

```mermaid
sequenceDiagram
    participant Cron as Scheduler
    participant WF1 as Lead Scraper
    participant API as Company API
    participant GS as Google Sheets
    participant WF2 as Lead Enrichment
    participant Apollo as Apollo.io
    participant Clearbit as Clearbit
    participant Claude as Claude AI
    participant WF3 as Notification Hub
    participant Slack as Slack
    participant Email as Email

    Note over Cron: 9:00 AM Monday
    Cron->>WF1: Trigger daily run
    WF1->>API: GET /companies?industry=tech
    API-->>WF1: 100 companies
    WF1->>WF1: Transform + Score (0-100)
    WF1->>WF1: Remove duplicates
    WF1->>GS: Append 47 new leads

    loop For each hot lead (score ≥ 70)
        WF1->>WF2: POST webhook (new lead)
        par Parallel enrichment
            WF2->>Apollo: GET /people/match
            Apollo-->>WF2: Decision makers
        and
            WF2->>Clearbit: GET /companies/find
            Clearbit-->>WF2: Company metrics
        end
        WF2->>WF2: Merge enrichment data
        WF2->>Claude: POST /v1/messages (analyze)
        Claude-->>WF2: Score + insights JSON
        WF2->>WF2: Final score = rule×0.4 + AI×0.6
        WF2->>GS: Update row with enrichment

        alt Final score ≥ 75 (high_priority)
            WF2->>WF3: POST notification event
            WF3->>Slack: Urgent alert to #sales
            WF3->>Email: Detailed email
        end
    end

    Note over WF1: End of run
    WF1->>WF3: POST daily_summary event
    WF3->>Email: Daily digest to sales team
```

---

## Layer 4: Detailed Node-by-Node Flow

What actually happens inside each node.

### Workflow 1: Lead Scraper — Step by Step

```mermaid
flowchart TD
    Start([9:00 AM Monday]) --> N1

    N1[📅 Schedule Trigger<br/>━━━━━━━━━━<br/>Cron: 0 9 * * 1-5<br/>Timezone: America/New_York]
    N1 --> N2

    N2[🌐 HTTP Request<br/>━━━━━━━━━━<br/>GET api.example.com/companies<br/>Auth: Bearer token<br/>Params: industry, size, location<br/>Returns: JSON array]
    N2 --> N3

    N3[⚙️ Code Node: Transform<br/>━━━━━━━━━━<br/>• Flatten nested objects<br/>• Extract 13 standard fields<br/>• Calculate lead_score 0-100<br/>• Assign quality_tier<br/>• Add scraped_at timestamp]
    N3 --> N4

    N4[🔁 Remove Duplicates<br/>━━━━━━━━━━<br/>Compare: company_name + website<br/>Keep: first occurrence]
    N4 --> N5

    N5[📊 Google Sheets<br/>━━━━━━━━━━<br/>Operation: appendOrUpdate<br/>Match on: company_name<br/>Columns: auto-mapped]
    N5 --> N6
    N5 --> Sum

    N6{🔀 IF Node<br/>━━━━━━━━━━<br/>quality_tier == 'hot'<br/>AND lead_score ≥ 70}
    N6 -->|TRUE| N7a
    N6 -->|TRUE| N7b
    N6 -->|FALSE| End1([Skip notification])

    N7a[💬 Slack Node<br/>━━━━━━━━━━<br/>Channel: #leads-alerts<br/>Rich formatted message<br/>Includes all lead details]
    N7a --> End2([Done])

    N7b[📧 Email Node<br/>━━━━━━━━━━<br/>To: sales-team@<br/>HTML formatted<br/>Table with metrics]
    N7b --> End2

    Sum[📈 Code Node: Summary<br/>━━━━━━━━━━<br/>Aggregate run stats<br/>hot/warm/cold counts<br/>Average score]
    Sum --> End3([Log summary])

    style N1 fill:#e3f2fd
    style N2 fill:#fff3e0
    style N3 fill:#f3e5f5
    style N4 fill:#f3e5f5
    style N5 fill:#e8f5e9
    style N6 fill:#fff9c4
    style N7a fill:#fce4ec
    style N7b fill:#fce4ec
```

### Workflow 2: Lead Enrichment — Parallel Processing Pattern

```mermaid
flowchart TD
    Start([External trigger:<br/>New lead created]) --> N1

    N1[🪝 Webhook Trigger<br/>━━━━━━━━━━<br/>Method: POST<br/>Path: /enrich-lead<br/>Response: async - handled later]

    N1 --> N2a
    N1 --> N2b

    N2a[🌐 Apollo API<br/>━━━━━━━━━━<br/>POST /v1/people/match<br/>Input: company_name, domain<br/>Output: decision makers list]

    N2b[🌐 Clearbit API<br/>━━━━━━━━━━<br/>GET /v2/companies/find<br/>Input: domain<br/>Output: tech stack, funding, revenue]

    N2a --> N3
    N2b --> N3

    N3[⚙️ Code Node: Merge<br/>━━━━━━━━━━<br/>Combines:<br/>• Original lead data<br/>• Apollo contacts<br/>• Clearbit metrics<br/>• Enrichment metadata]

    N3 --> N4

    N4[🤖 Claude AI<br/>━━━━━━━━━━<br/>POST api.anthropic.com/v1/messages<br/>Model: claude-sonnet-4-6<br/>Prompt: analyze + score<br/>Returns: JSON with score + insights]

    N4 --> N5

    N5[⚙️ Code Node: Final Score<br/>━━━━━━━━━━<br/>final = rule*0.4 + ai*0.6<br/>Assign final_tier:<br/>• ≥75: high_priority<br/>• ≥50: medium_priority<br/>• &lt;50: low_priority]

    N5 --> N6

    N6[📊 Google Sheets Update<br/>━━━━━━━━━━<br/>Update existing row<br/>Add enrichment columns<br/>Update lead_score]

    N6 --> N7

    N7{🔀 IF Node<br/>━━━━━━━━━━<br/>final_tier == 'high_priority'}

    N7 -->|TRUE| N8
    N7 -->|FALSE| N9

    N8[💬 Slack Urgent<br/>━━━━━━━━━━<br/>Channel: #sales-high-priority<br/>🚨 alert formatting<br/>Includes decision makers]
    N8 --> N9

    N9[📨 Respond to Webhook<br/>━━━━━━━━━━<br/>200 OK<br/>Returns: status, score, tier]
    N9 --> End([Complete])

    style N1 fill:#e3f2fd
    style N2a fill:#fff3e0
    style N2b fill:#fff3e0
    style N3 fill:#f3e5f5
    style N4 fill:#ffccbc
    style N5 fill:#f3e5f5
    style N6 fill:#e8f5e9
    style N7 fill:#fff9c4
    style N8 fill:#fce4ec
```

---

## Data Schema

### Lead Object Evolution

```mermaid
flowchart LR
    subgraph Raw["Raw Data<br/>(from API)"]
        R[name<br/>domain<br/>employees<br/>industry<br/>...]
    end

    subgraph Basic["After Scraper<br/>(13 fields)"]
        B[company_name<br/>website<br/>employee_count<br/>industry<br/>location<br/>contact_email<br/>phone<br/>linkedin_url<br/>description<br/>lead_score<br/>quality_tier<br/>scraped_at<br/>source]
    end

    subgraph Enriched["After Enrichment<br/>(+12 fields)"]
        E[+ decision_makers<br/>+ tech_stack<br/>+ funding_total<br/>+ annual_revenue<br/>+ company_type<br/>+ twitter_followers<br/>+ ai_score<br/>+ ai_insights<br/>+ ai_recommended_action<br/>+ final_score<br/>+ final_tier<br/>+ enriched_at]
    end

    Raw -->|Transform| Basic
    Basic -->|Enrich + AI| Enriched

    style Raw fill:#ffebee
    style Basic fill:#fff3e0
    style Enriched fill:#e8f5e9
```

### Core Lead Schema

| Field | Type | Source | Example |
|-------|------|--------|---------|
| `company_name` | string | Scraper | "TechFlow Solutions" |
| `website` | string | Scraper | "techflow.com" |
| `employee_count` | integer | Scraper | 150 |
| `industry` | string | Scraper | "SaaS" |
| `lead_score` | integer | Rule-based | 75 |
| `quality_tier` | enum | Rule-based | "hot" / "warm" / "cold" |
| `decision_makers` | array | Apollo | `[{name, title, email}]` |
| `tech_stack` | array | Clearbit | `["AWS", "React"]` |
| `ai_score` | integer | Claude | 82 |
| `ai_insights` | string | Claude | "Strong buying signals..." |
| `final_score` | integer | Calculated | 79 |
| `final_tier` | enum | Calculated | "high_priority" |

---

## Scoring Algorithm

### Rule-Based Scoring (Workflow 1)

```mermaid
flowchart LR
    subgraph Rules["Rule-Based Scoring (Max 100)"]
        R1[Employee Count 50-500<br/>+30 pts]
        R2[Has Contact Email<br/>+20 pts]
        R3[Has LinkedIn URL<br/>+15 pts]
        R4[Rich Description 50+ chars<br/>+15 pts]
        R5[Has Website<br/>+10 pts]
        R6[Has Phone<br/>+10 pts]
    end

    Rules --> Sum[Sum = lead_score]

    Sum --> Tier{Assign Tier}
    Tier -->|≥70| Hot[🔥 Hot]
    Tier -->|40-69| Warm[🌤 Warm]
    Tier -->|&lt;40| Cold[❄️ Cold]
```

### AI Scoring (Workflow 2)

Claude AI receives the full enriched lead and returns:

```json
{
  "score": 82,
  "action": "schedule_demo",
  "insights": "Strong product-market fit signals...",
  "buying_signals": ["recent funding", "hiring sales team"],
  "risk_factors": ["competing vendor"]
}
```

### Composite Scoring (Final)

```
final_score = (rule_score × 0.4) + (ai_score × 0.6)
```

**Why 60/40 weighting?** The AI catches nuanced signals rule-based scoring misses (hiring velocity, market momentum, strategic fit), but we still trust hard data (firmographics) with 40% weight for stability.

---

## Failure Handling

```mermaid
flowchart TD
    Start([Node execution]) --> Try{Try operation}

    Try -->|Success| Continue[Pass to next node]
    Try -->|API 5xx| Retry[Retry 3x with backoff]
    Try -->|API 4xx| Log[Log error + skip item]
    Try -->|Timeout| Alert[Alert admin Slack]
    Try -->|Rate limit| Wait[Wait + queue]

    Retry -->|Success| Continue
    Retry -->|Still fails| Log

    Log --> Partial[Continue with partial data]
    Wait --> Try
    Alert --> Partial

    Partial --> Continue

    style Try fill:#fff9c4
    style Continue fill:#c8e6c9
    style Log fill:#ffccbc
    style Alert fill:#ffcdd2
```

### Resilience Features

| Failure Type | Handling |
|--------------|----------|
| **API unavailable** | Skip that enrichment source, continue with partial data |
| **Rate limit hit** | Queue + retry with exponential backoff |
| **Bad data format** | Log error, skip record, continue batch |
| **AI API fails** | Fall back to rule-based score only |
| **Sheets write fails** | Retry 3x, then alert to #automation-errors |
| **Webhook timeout** | Async processing, acknowledge immediately |

---

## Why n8n?

```mermaid
flowchart LR
    subgraph Alternative["Custom Python Script"]
        P1[Write scraper]
        P2[Write scheduler]
        P3[Write error handling]
        P4[Write retry logic]
        P5[Write monitoring]
        P6[Deploy + maintain]
    end

    subgraph n8n["n8n Workflow"]
        N1[Drag nodes together]
        N2[Visual debugging]
        N3[Built-in retries]
        N4[Built-in monitoring]
        N5[200+ integrations ready]
    end

    Alternative -->|"2-3 weeks dev time"| Time1[📅 3 weeks]
    n8n -->|"2-3 hours config"| Time2[⏱ 3 hours]

    style Alternative fill:#ffccbc
    style n8n fill:#c8e6c9
```

**n8n advantages for this use case:**

- Visual workflow editor — non-engineers can modify
- Built-in error handling + retry logic
- 400+ pre-built integrations (no SDK coding)
- Self-hosted (data privacy) or cloud
- Low/no-code for simple cases, full code when needed
- Webhook + scheduling built-in
- Visual execution history for debugging

---

## Execution Example

**Scenario:** Monday 9 AM, the daily scrape runs.

| Time | Event | Outcome |
|------|-------|---------|
| 09:00:00 | Cron triggers Workflow 1 | Started |
| 09:00:02 | API returns 100 companies | Success |
| 09:00:05 | Transform + score complete | 100 leads, 12 hot, 35 warm, 53 cold |
| 09:00:06 | Dedup removes 8 existing | 92 new leads |
| 09:00:10 | Google Sheets updated | 92 rows added |
| 09:00:11 | IF node: 12 hot leads match | Fork |
| 09:00:12 | Slack + email fired for 12 leads | Notifications sent |
| 09:00:15 | Workflow 2 starts for each hot lead | 12 parallel enrichments |
| 09:00:25 | Apollo + Clearbit return | Decision makers + intel loaded |
| 09:00:35 | Claude AI analyzes each lead | AI scores 65-92 |
| 09:00:40 | Final scores calculated | 5 high_priority, 7 medium |
| 09:00:42 | Sheets updated with enrichment | Done |
| 09:00:43 | 5 urgent Slack alerts fired | Sales team notified |

**Total time: ~43 seconds** from trigger to sales team having actionable data.

---

## Summary: The Mental Model

Think of this system as a **3-stage factory assembly line**:

1. **Discovery Line (Scraper)** — Raw material comes in, gets basic quality check, sorted by grade
2. **Enhancement Line (Enrichment)** — High-grade items get decorated with extra details and AI quality inspection
3. **Shipping Line (Notifications)** — Finished products routed to the right customer (sales rep / channel)

Each line runs independently, triggered by events from the previous one, and all three share the same storage (Google Sheets = warehouse).
