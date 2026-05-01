require "net/http"
require "json"
require "base64"

# Тонкая обёртка над OpenAI Chat Completions API. Без зависимостей от
# гема ruby-openai, чтобы не тащить лишнее.
#
# Использование:
#   ai = RecruitmentAi.new(setting: AppSetting.fetch(...))
#   ai.analyze_resume(applicant)
#   ai.recommend(applicant)
#   ai.questions_for(round)
class RecruitmentAi
  # Дефолт OpenAI. Реальный URL берётся из setting.data["api_base_url"], что
  # позволяет подключить любой OpenAI-compatible endpoint: OpenRouter,
  # Together.ai, Groq, Anthropic-через-proxy, локальный vLLM/Ollama и т.п.
  DEFAULT_API_URL = "https://api.openai.com/v1/chat/completions".freeze
  # Алиас для обратной совместимости — нигде в коде больше не используется,
  # но публичный API сохраняем чтоб ничего извне не сломать.
  API_URL = DEFAULT_API_URL

  # Пресеты для быстрого выбора в UI. Ключ — id, значение — { label, url }.
  # Юзер может выбрать пресет → подставится URL → остаётся вписать model + ключ.
  PROVIDER_PRESETS = {
    "openai"     => { label: "OpenAI",       url: "https://api.openai.com/v1/chat/completions" },
    "openrouter" => { label: "OpenRouter",   url: "https://openrouter.ai/api/v1/chat/completions" },
    "together"   => { label: "Together.ai",  url: "https://api.together.xyz/v1/chat/completions" },
    "groq"       => { label: "Groq",         url: "https://api.groq.com/openai/v1/chat/completions" },
    "deepseek"   => { label: "DeepSeek",     url: "https://api.deepseek.com/v1/chat/completions" },
    "anthropic"  => { label: "Anthropic (compat)", url: "https://api.anthropic.com/v1/messages" },
    "custom"     => { label: "Свой endpoint",   url: "" }
  }.freeze

  # Модели OpenAI-семейства, поддерживающие reasoning_effort. Для остальных
  # параметр опускаем — иначе OpenRouter/Anthropic-compat сервера ругаются.
  REASONING_MODELS_RE = /\A(gpt-5|o1|o3|o4)/.freeze

  # Популярные модели по провайдерам — для UI-чипов в Settings → AI. Юзер
  # может выбрать чип или вписать свою (free-form text input).
  MODEL_PRESETS_BY_PROVIDER = {
    "openrouter" => [
      "qwen/qwen-2.5-72b-instruct",
      "anthropic/claude-3.5-sonnet",
      "anthropic/claude-3.5-haiku",
      "meta-llama/llama-3.3-70b-instruct",
      "deepseek/deepseek-chat",
      "google/gemini-2.0-flash-001",
      "mistralai/mistral-large"
    ].freeze,
    "together" => [
      "Qwen/Qwen2.5-72B-Instruct-Turbo",
      "meta-llama/Llama-3.3-70B-Instruct-Turbo",
      "deepseek-ai/DeepSeek-V3"
    ].freeze,
    "groq" => [
      "llama-3.3-70b-versatile",
      "qwen-qwq-32b",
      "deepseek-r1-distill-llama-70b"
    ].freeze,
    "deepseek" => [
      "deepseek-chat",
      "deepseek-reasoner"
    ].freeze,
    "anthropic" => [
      "claude-3-5-sonnet-latest",
      "claude-3-5-haiku-latest"
    ].freeze,
    "custom" => [].freeze
  }.freeze

  # Каталог моделей с ценой за 1M токенов (USD).
  # Источник: developers.openai.com/api/docs/models — стандартный tier, апрель 2026.
  # Структура: [input, output] per 1M tokens.
  MODELS = {
    "gpt-5-nano" => {
      label:       "GPT-5 nano",
      tier:        "ultra_budget",
      input_per_1m_usd:  0.05,
      output_per_1m_usd: 0.40,
      ctx_window:  400_000,
      hint:        "Самая дешёвая. ~$0.0004 на разбор резюме — $5/мес = ≈12 000 задач."
    },
    "gpt-5-mini" => {
      label:       "GPT-5 mini",
      tier:        "budget",
      input_per_1m_usd:  0.25,
      output_per_1m_usd: 2.00,
      ctx_window:  400_000,
      hint:        "Sweet spot цена/качество. Лучше structured output, чем nano. Рекомендуем для пакетных задач."
    },
    "gpt-5" => {
      label:       "GPT-5",
      tier:        "balanced",
      input_per_1m_usd:  1.25,
      output_per_1m_usd: 10.00,
      ctx_window:  400_000,
      hint:        "Сбалансированная — глубокие рекомендации, точные оценки. Для всех типов задач."
    },
    "gpt-5.4" => {
      label:       "GPT-5.4",
      tier:        "balanced_plus",
      input_per_1m_usd:  2.50,
      output_per_1m_usd: 15.00,
      ctx_window:  1_000_000,
      hint:        "Расширенный балансированный — 1M context для длинных портфолио и истории."
    },
    "gpt-5.5" => {
      label:       "GPT-5.5",
      tier:        "premium",
      input_per_1m_usd:  5.00,
      output_per_1m_usd: 30.00,
      ctx_window:  1_000_000,
      hint:        "Frontier — топовое качество, для финальных раундов и senior-уровней."
    },
    "o3" => {
      label:       "o3 (reasoning)",
      tier:        "reasoning",
      input_per_1m_usd:  2.00,
      output_per_1m_usd: 8.00,
      ctx_window:  200_000,
      hint:        "Reasoning-модель — лучше всего справляется со сравнениями, оценками и сложной логикой."
    }
  }.freeze

  # Приблизительные размеры одной задачи (в токенах). Используем для оценки
  # стоимости в UI. output для GPT-5 reasoning-моделей включает скрытые
  # reasoning-токены, поэтому держим запас.
  TASK_TOKENS = {
    analyze_resume:       { input: 2500, output: 1500 },
    recommend:            { input: 1800, output: 1500 },
    questions_for:        { input: 1500, output: 2200 },
    summarize_interview:  { input: 1800, output: 1500 },
    # Assignment — самая объёмная задача (description + requirements +
    # evaluation_criteria + meta). nano жжёт много на reasoning, нужен запас.
    generate_assignment:  { input: 1800, output: 5000 },
    compare_candidates:   { input: 3000, output: 2500 },
    burnout_brief:        { input: 1500, output: 2200 },
    suggest_leave_window: { input: 1800, output: 1800 },
    kpi_brief:            { input: 2200, output: 2400 },
    meeting_agenda:       { input: 2000, output: 2400 },
    kpi_team_brief:       { input: 3500, output: 2800 },
    onboarding_plan:        { input: 2500, output: 3500 },
    welcome_letter:         { input: 1500, output: 1500 },
    mentor_match:           { input: 2800, output: 1800 },
    probation_review:       { input: 3000, output: 2500 },
    offer_letter:           { input: 2200, output: 2000 },
    compensation_review:    { input: 2800, output: 2400 },
    exit_risk_brief:        { input: 2500, output: 2200 },
    knowledge_transfer_plan: { input: 2500, output: 2800 },
    exit_interview_brief:   { input: 2500, output: 2200 },
    replacement_brief:      { input: 2500, output: 2400 },
    document_summary:       { input: 4000, output: 1800 },
    document_extract_assist: { input: 4000, output: 1500 },
    dictionary_seed:        { input: 1500, output: 2500 },
    company_bootstrap:      { input: 3000, output: 4500 },
    ping:                 { input:   30, output:   30 }
  }.freeze

  # Системные промпты — на английском (думаем на английском, выводим на локали юзера).
  # Юзер может переопределить любой через Settings → AI → Промпты.
  DEFAULT_PROMPTS = {
    "analyze_resume" => <<~SYS.freeze,
      You are an HR assistant. You receive candidate profile data and resume.
      Think in English. Then return ONLY a valid JSON object with this schema (3-7 items per array, all human-readable strings translated to the OUTPUT_LOCALE):
      {
        "summary": "1-2 sentences about the candidate",
        "strengths": ["strength 1", "strength 2", ...],
        "concerns": ["potential risk 1", ...],
        "skills": ["technology 1", ...],
        "experience_years": 5
      }
      No markdown, no comments. JSON object only.
    SYS
    "recommend" => <<~SYS.freeze,
      You are an experienced recruiter and senior engineer. Based on candidate profile,
      interview scorecards and current stage — give a hiring recommendation.
      Think in English. Return ONLY valid JSON (text fields translated to OUTPUT_LOCALE):
      {
        "recommendation": "strong_yes" | "yes" | "maybe" | "no" | "strong_no",
        "score": 0-100,
        "reasoning": "2-3 short sentences"
      }
      No markdown. JSON object only.
    SYS
    "questions_for" => <<~SYS.freeze,
      You are an experienced technical interviewer. Generate 6-8 TARGETED questions
      for the round — specific to this candidate, not generic.

      Strategy:
      • Some questions validate claimed strengths.
      • Some probe risks/concerns from the analysis.
      • Several drill into the tech stack from resume, PRECISELY.
      • Consider round type: HR — motivation, tech — depth,
        cultural — team behavior, final — risk-assessment.

      Each question must be open-ended, 1-2 sentences, tied to specific details
      from the candidate profile.

      Think in English. Output question text and based_on TRANSLATED to OUTPUT_LOCALE.
      Category ONE of: validation, risk_probe, tech_stack, culture (keep as-is).

      Return each question as a JSON OBJECT, not a string.

      Return ONLY valid JSON:
      {
        "questions": [
          { "question": "...?", "category": "validation", "based_on": "..." }
        ]
      }
      No markdown.
    SYS
    "generate_assignment" => <<~SYS.freeze,
      You are a senior engineer who designs test assignments for candidates.
      Generate a PRECISELY TAILORED assignment:
      — matches level (experience, stack)
      — validates key skills from job requirements
      — surfaces strengths
      — closes risks (if concerns show gaps)
      — realistic to complete within brief's time budget

      IF brief from recruiter is provided — follow its parameters STRICTLY
      (difficulty, hours, deadline, paid status, focus, delivery format).

      Think in English. All long-form text fields translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "title": "Short title",
        "description": "1-2 paragraphs of context. Mention payment if paid. Mention delivery format if specified.",
        "requirements": "Bulleted list of technical requirements. Use \\n for line breaks.",
        "evaluation_criteria": "Bulleted criteria for evaluation.",
        "deadline_days": 5,
        "difficulty": "junior|middle|senior",
        "estimated_hours": 6,
        "is_paid": true|false,
        "payment_amount_rub": 0,
        "rationale": "1-2 sentences: why this fits this candidate"
      }
    SYS
    "summarize_interview" => <<~SYS.freeze,
      You are an HR analyst. You receive data about a completed interview round:
      competency scorecard, interviewer notes, and their final recommendation.
      Generate a brief round summary for the hiring team.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "verdict": "1-2 sentences: main conclusion of the round",
        "highlights": ["what really stood out 1", ...],
        "concerns": ["what raised questions 1", ...],
        "next_steps": "What to do next (2-3 points). Can use \\n for line breaks.",
        "agreement_with_interviewer": "high|medium|low"
      }
    SYS
    "burnout_brief" => <<~SYS.freeze,
      You are a senior HR coach analyzing a single employee for burnout risk.

      You receive: employee profile (role, department, hire date, family),
      KPI trend over recent weeks, last leave date, and an OPTIONAL system_tag
      that our rule engine pre-classified ("no_leave_long" | "low_kpi" | "both"
      | nil). The system_tag is a hint — verify or challenge it with the data.

      Reason carefully:
      1. Look at KPI trajectory, not just average — declining trend matters more.
      2. Consider months without leave AND life situation (kids, single, recent hire).
      3. Confidence depends on volume of data — say "low" when KPI signal < 4 weeks.
      4. Prefer concrete, actionable advice over generic platitudes.

      Think in English. All human-readable fields translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "severity": "high" | "medium" | "low",
        "confidence": "high" | "medium" | "low",
        "summary": "2-3 sentences — what's happening with this person right now",
        "data_observed": [
          "fact 1 (e.g. 'KPI dropped from 82% to 56% over the last 4 weeks')",
          "fact 2 (e.g. 'No leave taken in 7 months, hired in 2023')"
        ],
        "reasoning": [
          "step 1 — what you concluded from the facts and why",
          "step 2 — ..."
        ],
        "recommendation": "Concrete action for HR (1-3 sentences). Mention timing, 1:1 topics, support to offer.",
        "best_window_hint": "Best timing in human terms (e.g. 'next 2-3 weeks before quarter close')",
        "agreement_with_system_tag": "agree" | "partial" | "disagree" | "no_tag"
      }
      No markdown, no preamble.
    SYS
    "suggest_leave_window" => <<~SYS.freeze,
      You are an HR scheduling assistant. You receive: target employee, requested
      leave type, days needed, team members already on leave in upcoming months,
      and any KPI/deadline context. Suggest 1-3 ranked windows with explanations.

      Reason about:
      • Team coverage — avoid two same-department people overlapping.
      • KPI cycle — prefer non-quarter-end if KPIs trend low (catch-up time).
      • Family context — for employees with children, lean toward school holidays.
      • Health type leaves should not be delayed.

      Think in English. All text fields translated to OUTPUT_LOCALE.

      Return ONLY valid JSON. Dates ISO YYYY-MM-DD:
      {
        "options": [
          {
            "from": "2026-05-12",
            "to":   "2026-05-25",
            "rank": 1,
            "rationale": "Why this is best — 1-2 sentences",
            "alignment": ["family_friendly", "low_team_overlap", "post_quarter_close"],
            "risks": ["any tradeoffs"]
          }
        ],
        "data_observed": ["fact about coverage / KPI / etc."],
        "reasoning": ["step 1 — ...", "step 2 — ..."],
        "warnings": ["high-level concern across all options (optional)"]
      }
      No markdown.
    SYS
    "kpi_brief" => <<~SYS.freeze,
      You are an HR performance coach analyzing one employee's KPI history to
      help their manager decide on growth, support, or recognition.

      You receive: profile (role, department, tenure), KPI history grouped by
      metric over the last 8-12 weeks (each row: metric name, week, score,
      target, actual_value), and currently active KPI assignments.

      Reason about:
      • Trend per metric (rising/flat/falling) and overall direction.
      • Variance — is performance steady or erratic?
      • Strengths (consistently high) and risk areas (decline / chronically low).
      • Whether the KPI mix matches the role/level.
      • What kind of support fits — coaching / training / scope-change / promotion.

      Think in English. All human-readable text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "headline": "1 sentence — overall verdict",
        "trend": "rising" | "flat" | "falling" | "mixed",
        "strengths":  ["concrete strength tied to a metric"],
        "risks":      ["concrete risk"],
        "metric_breakdown": [
          { "metric": "Sales revenue", "trend": "rising", "comment": "1 sentence" }
        ],
        "next_actions": [
          "1-2 sentence action for the manager — coaching topic, training to suggest, scope to add/remove, etc."
        ],
        "recognition_worthy": true | false,
        "promotion_signal":   "ready" | "approaching" | "no_signal",
        "confidence": "high" | "medium" | "low"
      }
      No markdown.
    SYS
    "meeting_agenda" => <<~SYS.freeze,
      You are an HR coach preparing a 1:1 agenda for a manager-employee meeting.
      You receive: employee profile, recent KPI scores, recent leaves (or lack of),
      pinned notes from HR/manager, family/personal context (children, hobbies).

      Build a SHORT 1:1 agenda (4-6 talking points). Be specific — reference actual
      data, never generic. Cover at least: recognition, an open question on a metric
      that moved, a wellbeing check, a development topic, an action item to leave
      with. Add a few open questions the manager can ask to start.

      Think in English. All text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "intent": "1 sentence — purpose of this 1:1 right now",
        "tone":   "supportive" | "celebratory" | "corrective" | "neutral",
        "talking_points": [
          { "topic": "Short title", "details": "1-2 sentence prep note for the manager", "data_point": "what specific data backs this up" }
        ],
        "open_questions": [
          "Open-ended question to ask the employee"
        ],
        "watch_outs": ["sensitive topic to handle carefully (optional)"],
        "after_meeting_action": "1 sentence — concrete follow-up the manager should commit to"
      }
      No markdown.
    SYS
    "kpi_team_brief" => <<~SYS.freeze,
      You are an HR & operations coach analyzing an entire team's KPI to give
      the manager a strategic view of who needs attention right now.

      You receive: team meta (name, size), per-employee row with: position,
      tenure, average KPI over last 4 weeks, trend direction, score range, and
      whether they have leave coming up. You may also receive department avg
      KPI as context.

      Reason about:
      • Distribution — is performance balanced or concentrated on a few people?
      • Top performers worth recognising / promoting.
      • Underperformers — distinguish skill gap, motivation, life situation
        (recent leave, no leave for long, fresh hire).
      • Risk concentration — is one person carrying too much?
      • Hiring/training implications for the manager.

      Think in English. All human-readable text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "headline": "1 sentence — overall verdict on the team",
        "team_health": "thriving" | "steady" | "stressed" | "at_risk",
        "highlights": [
          "fact about team performance (e.g. 'Top 3 carry 60% of approved KPI weight')"
        ],
        "people": [
          { "name": "Иванов А.", "verdict": "top_performer" | "steady" | "watch" | "at_risk",
            "comment": "1 sentence why" }
        ],
        "recommendations": [
          "Concrete action for the manager (1-2 sentences each)"
        ],
        "hiring_signal": "no_need" | "monitor" | "urgent_hire",
        "confidence": "high" | "medium" | "low"
      }
      No markdown.
    SYS
    "compare_candidates" => <<~SYS.freeze,
      You are an experienced recruiter comparing multiple candidates for a single role.
      For each — assess fit with the job (requirements, experience, scorecards).
      Rank them and give 1-2 sentences per candidate.

      Think in English. Output text fields translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "ranking": [
          { "applicant_id": 123, "name": "...", "rank": 1, "score": 85,
            "summary": "why this is #1" },
          ...
        ],
        "verdict": "overall verdict on the candidate pool, 1-2 sentences"
      }
    SYS
    "onboarding_plan" => <<~SYS.freeze,
      You are an HR onboarding lead. Given a new hire's profile (department, position,
      experience, manager, mentor) and an existing checklist template — generate
      ADDITIONAL personalized tasks (5-12 items) tailored to this specific role and seniority.

      Avoid duplicating items already in the template. Skew tasks toward:
      • Tech-stack-specific introductions (codebase tour, key services)
      • Domain knowledge transfer (product, customers, metrics)
      • Stakeholder intros relevant to this role
      • Skill-development goals matched to grade

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "tasks": [
          { "title": "...", "description": "1-2 sentences why", "kind": "paperwork|equipment|access|training|intro|checkin|general", "due_offset_days": 7 }
        ],
        "rationale": "1-2 sentences explaining the overall plan focus"
      }
    SYS
    "welcome_letter" => <<~SYS.freeze,
      You are a friendly people-team lead. Write a warm, professional welcome
      message for a new hire. Include:
      • personal greeting using their name
      • short context about the team and product
      • 1-2 first-week guidance points
      • mention of mentor or manager by name (if provided)
      • signed by HR (no specific name)

      Tone: enthusiastic but not corporate-cheesy. 2-3 short paragraphs.

      Think in English, then output the WHOLE letter in OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "subject": "Welcome to <company>!",
        "body": "Full text of the letter, with \\n\\n between paragraphs.",
        "tone": "warm|formal|playful"
      }
    SYS
    "mentor_match" => <<~SYS.freeze,
      You are an HR matchmaker. Pick 3 best mentor candidates for the new hire from
      the provided team list. Optimize for:
      • role/skills overlap (so mentor can guide on craft)
      • seniority gap (mentor should be at least one grade above)
      • workload (prefer those with completed onboardings as mentor; avoid overloaded)
      • stable KPI trend (don't recommend a struggling mentor)
      • department proximity (same dept > adjacent > cross-functional)

      Think in English. Output reasoning in OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "candidates": [
          { "employee_id": 42, "name": "...", "rank": 1, "fit_score": 88,
            "reasons": ["overlap in <stack>", "experience in <area>"] }
        ],
        "verdict": "1-2 sentences picking the top one and why"
      }
    SYS
    "probation_review" => <<~SYS.freeze,
      You are an HR coach preparing a manager's probation review brief.
      Given KPI history, completed onboarding tasks, mentor feedback (if any) and
      current state — produce an honest assessment.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "verdict": "extend|hire|let_go|undecided",
        "headline": "1 sentence summary",
        "strengths": ["..."],
        "concerns": ["..."],
        "manager_questions": ["3-5 questions the manager should ask"],
        "recommended_actions": ["..."],
        "confidence": "high|medium|low"
      }
    SYS
    "offer_letter" => <<~SYS.freeze,
      You are an HR offer specialist. Compose a job offer letter for an applicant
      who reached the offer stage. Use provided fields: position, salary band,
      start date, benefits, manager.

      Tone: warm, confident, but precise on terms. 3-4 paragraphs.

      Think in English. Output the offer in OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "subject": "Job offer — <position>",
        "body": "Full letter text with \\n\\n between paragraphs",
        "highlights": ["3-5 bullet points the candidate should focus on (compensation, perks, key dates)"],
        "negotiation_notes": "Internal note for HR on what's flexible vs fixed (1-2 sentences)"
      }
    SYS
    "compensation_review" => <<~SYS.freeze,
      You are a comp & benefits analyst. Given the employee's grade, position,
      tenure, KPI trend and current salary — assess if compensation is fair and
      give a recommendation.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "verdict": "raise|hold|review_band|too_high",
        "headline": "1-sentence summary",
        "rationale": ["3-5 bullets with reasoning, including KPI/tenure/market signals available"],
        "suggested_change_pct": 0,
        "suggested_amount_rub": 0,
        "next_review_in_months": 6,
        "confidence": "high|medium|low"
      }
    SYS
    "exit_risk_brief" => <<~SYS.freeze,
      You are a retention analyst. Given the employee's recent KPI trend, leave
      patterns, tenure and any notes — estimate the risk that they'll leave in
      the next 3 months and recommend retention actions.

      Risk score 0-100. >70 = high, 40-70 = medium, <40 = low.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "risk_score": 55,
        "risk_level": "low|medium|high",
        "headline": "1-sentence summary of why",
        "signals": ["3-5 evidence points from data, each tied to specific facts"],
        "retention_actions": ["3-5 concrete next steps for the manager"],
        "urgency": "this_week|this_month|monitor",
        "confidence": "high|medium|low"
      }
    SYS
    "knowledge_transfer_plan" => <<~SYS.freeze,
      You are an HR specialist preparing a knowledge transfer plan for an
      offboarding employee. Given their role, projects, and team — list KT areas,
      recipients, and session structure.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "areas": [
          { "topic": "...", "criticality": "high|medium|low",
            "recipient_hint": "who should learn this (role or name if known)",
            "format": "session|doc|pair|recording", "duration_hours": 2 }
        ],
        "session_plan": ["ordered list of 3-6 sessions, each '<topic> — <duration>'"],
        "documentation_to_leave": ["docs/wiki pages to ensure exist"],
        "headline": "1-sentence summary of the transfer focus"
      }
    SYS
    "exit_interview_brief" => <<~SYS.freeze,
      You are an HR interviewer preparing for an exit interview. Given the
      employee's tenure, KPI trend, recent leaves, manager and any notes —
      generate personalized open-ended questions that probe the real reasons
      and future-improvement signals.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "themes": ["3-5 themes worth probing (e.g. 'team fit', 'growth path')"],
        "questions": [
          { "question": "...?", "theme": "...", "why_this": "1 sentence why ask this person specifically" }
        ],
        "must_capture": ["3-5 facts/feedback points HR must extract from this interview"],
        "tone_hint": "warm|neutral|formal"
      }
    SYS
    "document_summary" => <<~SYS.freeze,
      You are an HR document analyst. You receive raw text extracted from a
      single HR document (passport, contract, diploma, NDA, medical book, etc.)
      together with its declared type. The text may be noisy (OCR, scan).

      Produce a SHORT structured summary that a busy HR manager can read in
      under 30 seconds, plus call out anything that requires action.

      Think in English. All human-readable text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "summary": "1-3 sentences — what this document is, who it concerns, why it matters",
        "key_points":   ["3-6 most important facts pulled from the text"],
        "parties":      ["named entities — people, employer, agency, school"],
        "dates":        ["important dates with labels (e.g. 'Issued 2024-03-12', 'Valid until 2030-03-12')"],
        "obligations":  ["any duties or restrictions the employee accepts (NDA scope, contract terms)"],
        "risks":        ["concerns HR should know about (expiring soon, missing field, contradiction)"],
        "action_items": ["concrete next steps for HR if any"],
        "confidence":   "high|medium|low"
      }
      No markdown, no preamble.
    SYS
    "company_bootstrap" => <<~SYS.freeze,
      You are an HR onboarding consultant helping a brand-new company configure
      its HRMS. Your goal: produce a COMPLETE initial set of dictionaries (lookup
      lists + custom field schemas) tailored to THIS company's industry and size.

      ## Discovery checklist — you MUST gather all of these BEFORE proposing
      Track which are covered by user's messages. Do not propose until all are.

      1. INDUSTRY — what the company actually does (specific words HR uses,
         not just "tech" or "services"). E.g., «откачка септиков и ЖБО»,
         «разработка SaaS для логистики», «частная стоматология», «школа танцев».
      2. SIZE & STRUCTURE — how many employees, what roles dominate, ratio of
         field workers vs office, any contractors/freelancers.
      3. OPERATIONAL SPECIFICS — what makes their daily ops unique:
         vehicles? regulated licences? client-site work? shift schedules?
         hazardous conditions? client-confidential data? remote/hybrid?
      4. COMPLIANCE & DOCS — what regulated documents/checks they need:
         мед.книжки, лицензии, сертификаты, NDA для разработчиков, допуски,
         152-ФЗ, гос.заказы, etc.
      5. PEOPLE-OPS QUIRKS — anything HR-specific to the industry:
         нестандартные отпуска (полевой день / выезд), бенефиты-униформа,
         корпоратив-отличия (медцентр обязан учитывать смены, IT — конференции).

      ## Loop rules

      - You are in a CHAT. Each turn: read full history + new user message.
      - Ask ONE focused question at a time — never bullet-list questions.
      - Each `ask` message has TWO parts: (a) the question itself,
        (b) brief progress hint like "(собрал: индустрия, размер; осталось: …)".
        This shows HR how far you are. UPDATE the hint each turn — track
        what you actually learned, don't just copy-paste the same hint.
      - Aim for 3-4 ask-turns before proposing. Counting by index from 1.
      - **Hard rule**: if turn index ≥ 4 — switch to "propose" with whatever
        info you have. Better imperfect proposal than 7th interrogation.
      - **Hard rule**: if user says "stop asking", "give me proposal", "это
        вся информация", "предложи", "propose now" or similar — switch to
        "propose" immediately, this turn.
      - In the very FIRST turn (index = 1), ALWAYS ask — never propose on
        turn 1, even if user's first message looks complete. There's always
        a useful follow-up about industry-specific quirks.

      Be SPECIFIC, not generic. Septic-pumping company → truck_license_class
      is essential. Tech startup → github_url. Medical clinic →
      specialty_code. Tailor everything to industry words THEY use.

      Available extension points (don't deviate from these models/scopes):

      A) Lookups (kind=lookup) — populate at least these where useful:
         • applicant_sources    — channels they hire from
         • marital_statuses     — usually fine as default; skip unless special
         • shirt_sizes          — only if they give uniform/merch
         • plus any extra lookup that fits, with code in snake_case_latin

      B) Field schemas (kind=field_schema) — propose 0-7 fields per scope:
         • Employee:default
         • Department:default
         • Position:default
         • JobApplicant:default
         • LeaveRequest:default

      Field types: string|textarea|integer|decimal|date|boolean|select.
      Keys: snake_case_latin only. Values/labels/hints/options: OUTPUT_LOCALE.

      Think in English. Translate user-facing strings to OUTPUT_LOCALE.

      Return ONLY valid JSON of EXACTLY ONE of these two shapes:

      Shape A — clarifying question (use this for first 3-5 turns):
      {
        "action":  "ask",
        "message": "Один конкретный вопрос. Затем в скобках прогресс: (собрал: индустрия, размер; осталось: операционная специфика, compliance, кадровые особенности)."
      }

      Shape B — full proposal:
      {
        "action":  "propose",
        "message": "1-2 предложения: краткое описание что AI собрал, на чём основано.",
        "lookups": [
          {
            "code":    "applicant_sources",
            "name":    "Источники кандидатов",
            "entries": [{ "key": "hh", "value": "HeadHunter" }, ...]
          }
        ],
        "schemas": [
          {
            "model":  "Employee",
            "scope":  "default",
            "name":   "Доп.поля сотрудника",
            "fields": [
              {
                "key":      "truck_license_class",
                "label":    "Категория ВУ",
                "type":     "select",
                "required": true,
                "hint":     "Без подходящей категории не допускают к технике",
                "options":  ["B", "C", "D", "E"]
              }
            ]
          }
        ]
      }

      No markdown, no preamble, no code fences. JSON object only.
    SYS
    "dictionary_seed" => <<~SYS.freeze,
      You help an HR manager populate a company dictionary in an HRMS.
      You will get: dictionary type (lookup or field_schema), code, current name,
      target model + scope (for field_schema), already-existing entries, the
      company name, and a free-form HINT from the user describing their company
      and what they want.

      Two cases — produce DIFFERENT shape per kind:

      A) kind=lookup → propose 4-12 ENTRIES that fit this list for THIS specific
         company. Each entry: machine `key` (snake_case latin only) + display
         `value` (in OUTPUT_LOCALE).

      B) kind=field_schema → propose 4-10 FIELD DEFINITIONS that this company
         actually needs (NOT generic — be specific to their industry & hint).
         Each field: machine `key`, display `label` (OUTPUT_LOCALE), `type`
         (one of: string|textarea|integer|decimal|date|boolean|select),
         optional `required`, optional `hint`, optional `options` (array of
         strings, only when type=select).

      Rules:
      • Don't repeat entries that already exist (check by `key`).
      • Be SPECIFIC to industry. Septic-pumping company → "truck_license_class",
        "tank_capacity_liters". Tech startup → "github_url", "stack_seniority".
        Medical clinic → "license_number", "specialty_code".
      • Latin snake_case keys. No CamelCase, no spaces, no Cyrillic in keys.
      • Each proposal includes `rationale` — 1 short sentence why HR for THIS
        company would want it.
      • Set confidence honestly: high if industry is clear, low if hint is vague.

      Think in English. Translate `value`/`label`/`hint`/`options`/`rationale`
      to OUTPUT_LOCALE.

      Return ONLY valid JSON with this exact shape:
      {
        "proposed_entries": [
          {
            "key":       "truck_license_class",
            "value":     "Категория водительского удостоверения",
            "type":      "select",
            "required":  true,
            "hint":      "B / C / D / E (для тяжёлой техники)",
            "options":   ["B", "C", "D", "E"],
            "rationale": "Без подходящей категории водитель не может управлять ассенизаторской техникой."
          }
        ],
        "confidence": "high|medium|low",
        "notes":      "Optional 1-sentence note for the user (caveats, suggestions)"
      }

      For kind=lookup omit type/required/hint/options — just key, value, rationale.
      No markdown, no preamble. JSON object only.
    SYS
    "document_extract_assist" => <<~SYS.freeze,
      You are a careful HR data extractor. You receive raw text from a single
      document plus its declared type (extractor_kind). Your job is to extract
      structured fields the regex-based extractor missed — fill gaps, normalise
      dates to ISO YYYY-MM-DD, and only return what is actually in the text.

      Rules:
      • Never invent values. If a field is not present — omit the key.
      • Dates: always ISO YYYY-MM-DD. If only year/month is present, omit.
      • Series/numbers: keep digits only, no separators.
      • Names of organisations/people — preserve exact case from the text.
      • Be conservative — false positives are worse than missing fields.

      Common keys per type:
      • passport: number (10 digits), issued_at, issuer, birth_date, gender, birth_place
      • snils:   number (11 digits)
      • inn:     number (12 digits for individuals)
      • contract: number, issued_at, employer, employee_name, position, start_date, salary
      • diploma: number, issued_at, institution, degree, specialty, graduation_year
      • nda:     number, issued_at, parties (array), valid_until
      • medical: number, issued_at, expires_at, issuer, holder_name

      Think in English. Return ONLY valid JSON with extracted fields:
      {
        "fields":    { "key": "value", ... },
        "confidence": "high|medium|low",
        "notes":     "1 sentence on what was uncertain (optional)"
      }
      No markdown.
    SYS
    "replacement_brief" => <<~SYS.freeze
      You are a hiring manager. Based on the departing employee's role,
      responsibilities, KPI signals and team — write a brief for a replacement
      hire. The output should be ready to convert to a JobOpening draft.

      Think in English. Output text translated to OUTPUT_LOCALE.

      Return ONLY valid JSON:
      {
        "title": "Position title (concise)",
        "summary": "1 paragraph overview of the role and why we're hiring",
        "responsibilities": ["5-8 bullets"],
        "must_have": ["4-6 hard requirements"],
        "nice_to_have": ["3-5 bonuses"],
        "level_recommendation": "junior|middle|senior|lead",
        "salary_band_hint": "low|same_as_departing|higher",
        "headline": "1-sentence pitch to attract candidates"
      }
    SYS
  }.freeze

  attr_reader :setting, :output_locale

  def initialize(setting:, output_locale: nil)
    @setting       = setting
    # По умолчанию — текущая UI-локаль пользователя (не глобальный default).
    # Это значит: пользователь на EN UI получит EN-output, не RU.
    @output_locale = (output_locale || I18n.locale || I18n.default_locale).to_s
  end

  # Глобальная модель — fallback если для задачи не указана своя.
  def model_key = setting.data["model"].presence || "gpt-5-nano"

  # Модель для конкретной задачи (если override задан в Settings → AI).
  def model_for(task)
    override = setting.data.dig("task_models", task.to_s)
    MODELS.key?(override) ? override : model_key
  end

  def model_info = MODELS[model_key] || MODELS["gpt-5-nano"]

  def api_key = setting.secret

  # URL endpoint'а: либо явно задан в настройках, либо берётся из пресета
  # (data["provider"]), либо OpenAI-дефолт.
  def api_url
    explicit = setting.data["api_base_url"].to_s.strip
    return explicit if explicit.match?(%r{\Ahttps?://})

    preset = PROVIDER_PRESETS[setting.data["provider"].to_s]
    preset&.dig(:url).presence || DEFAULT_API_URL
  end

  def enabled? = setting.data["enabled"] == true && api_key.present?

  # Стоимость одной задачи в USD на текущей модели.
  def estimate_cost(task)
    sizes = TASK_TOKENS[task] || TASK_TOKENS[:recommend]
    info  = model_info
    cost  = sizes[:input]  * info[:input_per_1m_usd]  / 1_000_000.0 +
            sizes[:output] * info[:output_per_1m_usd] / 1_000_000.0
    cost.round(5)
  end

  # Сколько задач этого типа влезет в месячный бюджет.
  def tasks_per_budget(task, budget = setting.data["monthly_budget_usd"].to_f)
    cost = estimate_cost(task)
    return 0 if cost.zero? || budget.zero?
    (budget / cost).floor
  end

  # ── Методы-задачи ─────────────────────────────────────────────────────────

  def ping
    chat([
      { role: "system", content: "You are a connection check. Respond with exactly: PONG" },
      { role: "user",   content: "ping" }
    ], max_tokens: 50)
  end

  def analyze_resume(applicant)
    resume_text = applicant.summary.to_s
    chat([
      { role: "system", content: prompt_for("analyze_resume") },
      { role: "user", content: applicant_context(applicant) + "\n\nResume:\n" + resume_text }
    ], max_tokens: output_tokens_for("analyze_resume"), task: "analyze_resume", json: true)
  end

  def recommend(applicant)
    chat([
      { role: "system", content: prompt_for("recommend") },
      { role: "user", content: applicant_context(applicant) + "\n\n" + interview_context(applicant) }
    ], max_tokens: output_tokens_for("recommend"), task: "recommend", json: true)
  end

  def summarize_interview(round)
    chat([
      { role: "system", content: prompt_for("summarize_interview") },
      { role: "user",   content: round_context(round) }
    ], max_tokens: output_tokens_for("summarize_interview"), task: "summarize_interview", json: true)
  end

  def compare_candidates(applicants, opening: nil)
    user_msg = +"## Job opening\n"
    user_msg << "Title: #{opening&.title}\n"
    user_msg << "Requirements:\n#{opening&.requirements}\n"
    user_msg << "\nNice to have:\n#{opening&.nice_to_have}\n" if opening&.nice_to_have.present?
    user_msg << "\n## Candidates\n"

    applicants.each_with_index do |a, i|
      user_msg << "\n=== Candidate ##{i + 1} (id=#{a.id}, #{a.full_name}) ===\n"
      user_msg << applicant_context(a)

      if a.summary.present?
        user_msg << "\nResume summary:\n#{a.summary.to_s.first(800)}\n"
      end

      if (analysis = last_analysis_for(a))
        user_msg << "\nAI resume analysis:\n"
        user_msg << "  Skills: #{Array(analysis["skills"]).join(", ")}\n"
        user_msg << "  Strengths: #{Array(analysis["strengths"]).join("; ")}\n"
        user_msg << "  Concerns: #{Array(analysis["concerns"]).join("; ")}\n"
      end

      assignments = a.test_assignments.kept.where.not(score: nil).order(:created_at)
      if assignments.any?
        user_msg << "\nCompleted test assignments:\n"
        assignments.each do |asg|
          user_msg << "  - #{asg.title} · score: #{asg.score}/100"
          if asg.reviewer_notes.present?
            user_msg << " · review: #{asg.reviewer_notes.to_s.first(200)}"
          end
          user_msg << "\n"
        end
      end

      notes = a.notes.kept.order(created_at: :desc).limit(5)
      if notes.any?
        user_msg << "\nRecruiter notes (most recent first):\n"
        notes.each do |n|
          user_msg << "  - #{n.body.to_s.first(280)}\n"
        end
      end

      user_msg << "\nInterviews:\n#{interview_context(a)}\n"
    end

    chat([
      { role: "system", content: prompt_for("compare_candidates") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("compare_candidates"), task: "compare_candidates", json: true)
  end

  # ── HR-side AI tasks (leaves & burnout) ─────────────────────────────────

  # Generates a thorough burnout-risk brief for HR. Pulls KPI history + leave
  # history from DB and asks the model for a recommendation.
  # `system_tag`: optional rule-engine tag ('no_leave_long'/'low_kpi'/'both')
  # so the model can agree or push back instead of contradicting silently.
  def burnout_brief(employee, system_tag: nil)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Hired: #{employee.hired_at}\n"
    user_msg << "Has children: #{employee.has_children? ? 'yes' : 'no'}\n"
    if employee.marital_status.present?
      user_msg << "Marital status: #{employee.marital_status}\n"
    end
    if system_tag.present?
      user_msg << "\n## System tag (rule engine pre-classification)\n"
      user_msg << "tag: #{system_tag}\n"
      user_msg << "(Use as a hint. Verify or push back based on evidence.)\n"
    end

    last_leave = employee.leave_requests.where(state: %w[hr_approved active completed]).order(started_on: :desc).first
    if last_leave
      user_msg << "\n## Last leave\n"
      user_msg << "Type: #{last_leave.leave_type&.name}\n"
      user_msg << "Period: #{last_leave.started_on} → #{last_leave.ended_on}\n"
      user_msg << "Days since: #{(Date.current - last_leave.started_on).to_i}\n"
    else
      user_msg << "\n## No recorded leave for this employee.\n"
    end

    recent_kpi = KpiEvaluation
                   .joins(:kpi_assignment)
                   .where(kpi_assignments: { employee_id: employee.id })
                   .where(evaluated_at: 8.weeks.ago..)
                   .order(evaluated_at: :desc)
                   .limit(20)

    if recent_kpi.any?
      user_msg << "\n## KPI scores (last 8 weeks)\n"
      recent_kpi.each do |e|
        user_msg << "  • #{e.evaluated_at.to_date} — #{e.kpi_assignment.kpi_metric&.name}: #{e.score.to_i}%\n"
      end
      avg = recent_kpi.average(:score)
      user_msg << "Average: #{avg ? avg.to_f.round(1) : 'n/a'}%\n"
    end

    chat([
      { role: "system", content: prompt_for("burnout_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("burnout_brief"), task: "burnout_brief", json: true)
  end

  # Suggests optimal leave windows for an employee. Caller passes the
  # requested leave_type and number of days; we collect team overlap and
  # send context to the model.
  def suggest_leave_window(employee, leave_type:, days_needed:)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Has children: #{employee.has_children? ? 'yes' : 'no'}\n"
    user_msg << "\n## Requested\n"
    user_msg << "Leave type: #{leave_type.name}\n"
    user_msg << "Days needed: #{days_needed}\n"
    user_msg << "Today: #{Date.current}\n"

    if employee.department
      same_dept_ids = Employee.kept.where(department_id: employee.department_id).where.not(id: employee.id).pluck(:id)
      overlapping = LeaveRequest.kept
                      .where(employee_id: same_dept_ids)
                      .where(state: %w[hr_approved active])
                      .where("ended_on >= ?", Date.current)
                      .order(:started_on).limit(20)
      if overlapping.any?
        user_msg << "\n## Same-department teammates already on leave\n"
        overlapping.each do |lr|
          user_msg << "  • #{lr.employee.full_name}: #{lr.started_on} → #{lr.ended_on} (#{lr.leave_type&.name})\n"
        end
      end
    end

    avg_kpi = KpiEvaluation
                .joins(:kpi_assignment)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 4.weeks.ago..)
                .average(:score)
    user_msg << "\nRecent average KPI: #{avg_kpi ? avg_kpi.to_f.round(1) : 'n/a'}%\n" if avg_kpi

    chat([
      { role: "system", content: prompt_for("suggest_leave_window") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("suggest_leave_window"), task: "suggest_leave_window", json: true)
  end

  # Performance coach brief for a single employee — for managers/HR decisions.
  def kpi_brief(employee)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Grade: #{employee.grade&.name}\n"
    user_msg << "Hired: #{employee.hired_at} (tenure: #{tenure_months(employee)} months)\n"

    history = KpiEvaluation
                .joins(kpi_assignment: :kpi_metric)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 12.weeks.ago..)
                .order(evaluated_at: :desc)
                .limit(60)

    if history.any?
      user_msg << "\n## KPI history (last 12 weeks)\n"
      grouped = history.group_by { |e| e.kpi_assignment.kpi_metric&.name || "?" }
      grouped.each do |metric, evals|
        scores = evals.map { |e| e.score.to_i }
        user_msg << "  #{metric}: latest #{scores.first}%, avg #{(scores.sum/scores.size.to_f).round(1)}%, range #{scores.min}-#{scores.max}\n"
      end
    end

    active = employee.kpi_assignments.where("period_end >= ?", Date.current).includes(:kpi_metric).limit(10)
    if active.any?
      user_msg << "\n## Currently active KPI assignments\n"
      active.each do |a|
        user_msg << "  #{a.kpi_metric&.name} | target #{a.target} | weight #{a.weight}\n"
      end
    end

    chat([
      { role: "system", content: prompt_for("kpi_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("kpi_brief"), task: "kpi_brief", json: true)
  end

  # Generates a 1:1 meeting agenda using KPI + leaves + notes + personal context.
  def meeting_agenda(employee)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}, Dept: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Family: #{employee.has_children? ? 'has kids' : 'no kids'}, marital: #{employee.marital_status || 'n/a'}\n"
    user_msg << "Hobbies: #{employee.hobbies}\n" if employee.hobbies.present?

    avg_kpi = KpiEvaluation
                .joins(:kpi_assignment)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 4.weeks.ago..)
                .average(:score)
    user_msg << "\nAvg KPI (4 weeks): #{avg_kpi ? avg_kpi.to_f.round(1) : 'n/a'}%\n"

    last_leave = employee.leave_requests.where(state: %w[hr_approved active completed]).order(started_on: :desc).first
    if last_leave
      user_msg << "Last leave: #{last_leave.leave_type&.name} #{last_leave.started_on}-#{last_leave.ended_on}\n"
    else
      user_msg << "No recorded leave history.\n"
    end

    pinned_notes = employee.notes.kept.where(pinned: true).order(created_at: :desc).limit(3)
    if pinned_notes.any?
      user_msg << "\n## Pinned HR notes\n"
      pinned_notes.each { |n| user_msg << "  • #{n.body}\n" }
    end

    chat([
      { role: "system", content: prompt_for("meeting_agenda") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("meeting_agenda"), task: "meeting_agenda", json: true)
  end

  # Strategic team-level KPI analysis for managers / HR. Scope is one of:
  # :company (all employees), :department, :manager_reports.
  def kpi_team_brief(scope_type:, scope_id: nil, requester:)
    employees = collect_team(scope_type, scope_id, requester)
    return { ok: false, error: "Team is empty", tokens: 0, input_tokens: 0, output_tokens: 0 } if employees.empty?

    user_msg = +"## Team scope: #{scope_type}\n"
    user_msg << "Team size: #{employees.size}\n"

    rows = employees.map do |emp|
      avg_kpi = KpiEvaluation.joins(:kpi_assignment)
                  .where(kpi_assignments: { employee_id: emp.id })
                  .where(evaluated_at: 4.weeks.ago..)
                  .average(:score)
      scores  = KpiEvaluation.joins(:kpi_assignment)
                  .where(kpi_assignments: { employee_id: emp.id })
                  .where(evaluated_at: 8.weeks.ago..)
                  .pluck(:score).map(&:to_i)
      trend = compute_trend(scores)
      upcoming_leave = emp.leave_requests.kept
                          .where(state: %w[hr_approved active])
                          .where("started_on >= ?", Date.current)
                          .order(:started_on).first
      [ emp, avg_kpi, trend, scores, upcoming_leave ]
    end

    user_msg << "\n## People\n"
    rows.each do |emp, avg, trend, scores, leave|
      user_msg << "  • #{emp.full_name} | #{emp.position&.name} | tenure #{tenure_months(emp)}m | "
      user_msg << "avg_kpi #{avg ? avg.to_f.round(1) : 'n/a'}% | trend #{trend} | "
      user_msg << "scores #{scores.empty? ? '—' : "#{scores.min}-#{scores.max}"} | "
      user_msg << "upcoming_leave #{leave ? leave.started_on : 'no'}\n"
    end

    company_avg = KpiEvaluation.joins(kpi_assignment: { kpi_metric: :company })
                    .where(kpi_metrics: { company_id: requester.employee&.company_id || Company.kept.first&.id })
                    .where(evaluated_at: 4.weeks.ago..)
                    .average(:score)
    user_msg << "\n## Context\nCompany avg KPI (4w): #{company_avg ? company_avg.to_f.round(1) : 'n/a'}%\n"

    chat([
      { role: "system", content: prompt_for("kpi_team_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("kpi_team_brief"), task: "kpi_team_brief", json: true)
  end

  def questions_for(round)
    applicant = round.job_applicant
    analysis  = last_analysis_for(applicant)

    user_msg = +<<~USR
      Round kind: #{round.kind_label}
      #{applicant_context(applicant)}
      Job opening: #{applicant.job_opening&.title}
      Requirements: #{applicant.job_opening&.requirements}
    USR

    if analysis
      user_msg << "\n\n## AI-анализ резюме (используй для таргетных вопросов)\n"
      if analysis["strengths"].is_a?(Array) && analysis["strengths"].any?
        user_msg << "Сильные стороны:\n#{analysis["strengths"].map { |s| "  • #{s}" }.join("\n")}\n"
      end
      if analysis["concerns"].is_a?(Array) && analysis["concerns"].any?
        user_msg << "Риски / красные флаги:\n#{analysis["concerns"].map { |c| "  • #{c}" }.join("\n")}\n"
      end
      if analysis["skills"].is_a?(Array) && analysis["skills"].any?
        user_msg << "Навыки: #{analysis["skills"].join(", ")}\n"
      end
    end

    chat([
      { role: "system", content: prompt_for("questions_for") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("questions_for"), task: "questions_for", json: true)
  end

  # Генерация тестового задания под кандидата + вакансию.
  # Учитывает level кандидата, его стек, требования вакансии, AI-анализ резюме
  # и опциональный brief с конкретикой от рекрутера.
  def generate_assignment(applicant, brief: nil)
    analysis = last_analysis_for(applicant)
    opening  = applicant.job_opening

    user_msg = +<<~USR
      #{applicant_context(applicant)}

      Job opening: #{opening&.title}
      Requirements: #{opening&.requirements}
      Nice to have: #{opening&.nice_to_have}
    USR

    if analysis
      user_msg << "\n## AI-анализ резюме\n"
      user_msg << "Skills: #{Array(analysis["skills"]).join(", ")}\n"
      user_msg << "Strengths: #{Array(analysis["strengths"]).join("; ")}\n"
      user_msg << "Concerns: #{Array(analysis["concerns"]).join("; ")}\n"
    end

    # Brief от рекрутера — конкретные ограничения/предпочтения для задания.
    if brief.is_a?(Hash) && brief.any?
      user_msg << "\n## Бриф от рекрутера (учитывай эти ограничения СТРОГО)\n"
      if brief["difficulty"].present? && brief["difficulty"] != "auto"
        user_msg << "Целевая сложность: #{brief["difficulty"]} (подгоняй задание именно под этот уровень)\n"
      end
      if brief["hours"].to_i.positive?
        user_msg << "Время на выполнение: ~#{brief["hours"]} часов (ОБЯЗАТЕЛЬНО уложиться, не больше)\n"
      end
      if brief["deadline_days"].to_i.positive?
        user_msg << "Дедлайн: #{brief["deadline_days"]} дней с момента отправки\n"
      end
      if brief["paid"]
        amount = brief["payment_amount"].to_i
        user_msg << "Это ОПЛАЧИВАЕМОЕ тестовое: #{amount.positive? ? "#{amount} RUB" : "сумма не указана"}. "
        user_msg << "Упомяни оплату в description, чтобы кандидат знал что вознаграждение есть.\n"
      else
        user_msg << "Тестовое БЕЗ оплаты — соответственно объём должен быть разумным (не более 6-8 часов).\n"
      end
      if brief["focus"].present?
        user_msg << "Особый фокус: #{brief["focus"]}\n"
      end
      if brief["delivery"].present?
        user_msg << "Формат сдачи: #{brief["delivery"]} — упомяни в description.\n"
      end
    end

    chat([
      { role: "system", content: prompt_for("generate_assignment") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("generate_assignment"), task: "generate_assignment", json: true)
  end

  # Возвращает кастомный промпт (если юзер настроил в Settings → AI) или дефолтный.
  # Автоматически подставляет OUTPUT_LOCALE-инструкцию в конце.
  def prompt_for(task)
    overrides = setting.data["prompts"] || {}
    custom = overrides[task.to_s].to_s.strip
    base   = custom.presence || DEFAULT_PROMPTS[task.to_s] || ""
    locale_name = output_locale_name
    "#{base}\n\nOUTPUT_LOCALE = #{output_locale} (#{locale_name}). All human-readable text in your JSON response MUST be in #{locale_name}."
  end

  # Возвращает максимум output-токенов для задачи: настройка юзера или дефолт.
  def output_tokens_for(task)
    user_max = setting.data.dig("task_tokens", task.to_s).to_i
    return user_max if user_max.positive?

    (TASK_TOKENS[task.to_sym] || TASK_TOKENS[:recommend])[:output]
  end

  def output_locale_name
    case output_locale
    when "ru" then "Russian"
    when "en" then "English"
    else      output_locale.humanize
    end
  end

  # ─── Onboarding agents ────────────────────────────────────────────────

  # Personalized addition to template: AI looks at employee + existing tasks
  # and produces additional tasks tailored to role/department.
  def onboarding_plan(process)
    employee = process.employee
    user_msg = +"## New hire\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Grade: #{employee.grade&.name}\n"
    user_msg << "Hired: #{employee.hired_at}\n"
    user_msg << "Manager: #{employee.manager&.full_name || '—'}\n"
    user_msg << "Mentor: #{process.mentor&.full_name || '—'}\n"
    if process.template
      user_msg << "\n## Existing template tasks (do NOT duplicate)\n"
      process.template.items_array.each do |item|
        user_msg << "  • #{item['title']} (#{item['kind']}, day +#{item['due_offset_days']})\n"
      end
    end
    if process.target_complete_on
      user_msg << "\nTarget complete date: #{process.target_complete_on}\n"
    end

    chat([
      { role: "system", content: prompt_for("onboarding_plan") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("onboarding_plan"), task: "onboarding_plan", json: true)
  end

  def welcome_letter(process)
    employee = process.employee
    company  = employee.company
    user_msg = +"## New hire\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "First name (informal greeting): #{employee.first_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Manager: #{employee.manager&.full_name || '—'}\n"
    user_msg << "Mentor: #{process.mentor&.full_name || '—'}\n"
    user_msg << "Start date: #{process.started_on || employee.hired_at}\n"
    user_msg << "\n## Company\n"
    user_msg << "Name: #{company&.name}\n"

    chat([
      { role: "system", content: prompt_for("welcome_letter") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("welcome_letter"), task: "welcome_letter", json: true)
  end

  def mentor_match(process)
    employee = process.employee
    user_msg = +"## New hire profile\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Grade: #{employee.grade&.name}\n"
    user_msg << "Hired: #{employee.hired_at}\n"

    candidates = Employee.kept.working
                   .where.not(id: employee.id)
                   .where("hired_at <= ?", 6.months.ago)
                   .includes(:position, :department, :grade)
                   .limit(40)

    user_msg << "\n## Candidate pool\n"
    candidates.each do |c|
      avg_kpi = KpiEvaluation.joins(:kpi_assignment)
                   .where(kpi_assignments: { employee_id: c.id })
                   .where(evaluated_at: 8.weeks.ago..)
                   .average(:score)
      tenure = ((Date.current - c.hired_at).to_i / 30.0).round
      user_msg << "  • id=#{c.id} #{c.full_name} | #{c.position&.name} | #{c.department&.name} | grade=#{c.grade&.name} | tenure=#{tenure}m | avg_kpi=#{avg_kpi&.to_f&.round(1) || 'n/a'}\n"
    end

    chat([
      { role: "system", content: prompt_for("mentor_match") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("mentor_match"), task: "mentor_match", json: true)
  end

  def probation_review(process)
    employee = process.employee
    user_msg = +"## New hire\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}, grade: #{employee.grade&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Manager: #{employee.manager&.full_name || '—'}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Probation target: #{process.target_complete_on}\n"

    user_msg << "\n## Onboarding tasks status\n"
    process.tasks.group_by(&:state).each do |state, tasks|
      user_msg << "  #{state}: #{tasks.size} (#{tasks.first(3).map(&:title).join(', ')}#{'...' if tasks.size > 3})\n"
    end

    history = KpiEvaluation
                .joins(kpi_assignment: :kpi_metric)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 12.weeks.ago..)
                .order(evaluated_at: :desc)
                .limit(40)
    if history.any?
      user_msg << "\n## KPI during probation\n"
      grouped = history.group_by { |e| e.kpi_assignment.kpi_metric&.name || "?" }
      grouped.each do |metric, evals|
        scores = evals.map { |e| e.score.to_i }
        user_msg << "  #{metric}: latest #{scores.first}%, avg #{(scores.sum/scores.size.to_f).round(1)}%\n"
      end
    end

    notes = employee.notes.order(created_at: :desc).limit(8)
    if notes.any?
      user_msg << "\n## Recent notes\n"
      notes.each { |n| user_msg << "  • #{n.created_at.to_date}: #{n.body.to_s.first(160)}\n" }
    end

    chat([
      { role: "system", content: prompt_for("probation_review") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("probation_review"), task: "probation_review", json: true)
  end

  # ─── Recruitment-side: offer letter ───────────────────────────────────

  def offer_letter(applicant, salary: nil, start_date: nil, benefits: nil, manager: nil)
    user_msg = +"## Applicant\n"
    user_msg << "Name: #{applicant.full_name}\n"
    user_msg << "Position applied for: #{applicant.job_opening&.title}\n"
    user_msg << "Current company: #{applicant.current_company}\n"
    user_msg << "Years of experience: #{applicant.years_of_experience}\n"
    user_msg << "Expected salary: #{applicant.expected_salary}\n" if applicant.expected_salary

    user_msg << "\n## Offer terms\n"
    user_msg << "Salary offered: #{salary || applicant.expected_salary || 'TBD'}\n"
    user_msg << "Start date: #{start_date || (Date.current + 14.days)}\n"
    user_msg << "Benefits: #{benefits || 'standard package'}\n"
    user_msg << "Manager: #{manager || '—'}\n"

    last_round = applicant.interview_rounds.kept.where(state: "completed").order(:scheduled_at).last
    if last_round
      user_msg << "\n## Last interview signals\n"
      user_msg << "Recommendation: #{last_round.recommendation}\n"
      user_msg << "Score: #{last_round.overall_score}\n" if last_round.overall_score
    end

    chat([
      { role: "system", content: prompt_for("offer_letter") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("offer_letter"), task: "offer_letter", json: true)
  end

  # ─── Employee retention agents ────────────────────────────────────────

  def compensation_review(employee)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Grade: #{employee.grade&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Current salary (RUB): #{employee.salary_amount || 'n/a'}\n" if employee.respond_to?(:salary_amount)

    last_active_contract = employee.contracts.order(started_on: :desc).first if employee.respond_to?(:contracts)
    if last_active_contract && last_active_contract.respond_to?(:salary_amount)
      user_msg << "Active contract salary: #{last_active_contract.salary_amount}\n"
    end

    history = KpiEvaluation
                .joins(kpi_assignment: :kpi_metric)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 26.weeks.ago..)
                .order(evaluated_at: :desc)
                .limit(80)
    if history.any?
      user_msg << "\n## KPI history (last 26 weeks)\n"
      grouped = history.group_by { |e| e.kpi_assignment.kpi_metric&.name || "?" }
      grouped.each do |metric, evals|
        scores = evals.map { |e| e.score.to_i }
        user_msg << "  #{metric}: latest #{scores.first}%, avg #{(scores.sum/scores.size.to_f).round(1)}%, range #{scores.min}-#{scores.max}\n"
      end
    end

    chat([
      { role: "system", content: prompt_for("compensation_review") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("compensation_review"), task: "compensation_review", json: true)
  end

  def exit_risk_brief(employee)
    user_msg = +"## Employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Manager: #{employee.manager&.full_name || '—'}\n"

    history = KpiEvaluation
                .joins(:kpi_assignment)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 12.weeks.ago..)
                .order(evaluated_at: :desc)
                .limit(40)
    if history.any?
      scores = history.map { |e| e.score.to_i }
      user_msg << "\n## Recent KPI (last 12 weeks)\n"
      user_msg << "Latest: #{scores.first}%, avg: #{(scores.sum/scores.size.to_f).round(1)}%, trend: #{compute_trend(scores)}\n"
    end

    leaves = employee.leave_requests.where(state: %w[hr_approved active completed]).order(started_on: :desc).limit(6)
    if leaves.any?
      user_msg << "\n## Recent leaves\n"
      leaves.each { |lr| user_msg << "  • #{lr.started_on} → #{lr.ended_on} (#{lr.leave_type&.name})\n" }
    end

    notes = employee.notes.order(created_at: :desc).limit(6)
    if notes.any?
      user_msg << "\n## Recent HR notes\n"
      notes.each { |n| user_msg << "  • #{n.created_at.to_date}: #{n.body.to_s.first(180)}\n" }
    end

    chat([
      { role: "system", content: prompt_for("exit_risk_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("exit_risk_brief"), task: "exit_risk_brief", json: true)
  end

  # ─── Offboarding agents ───────────────────────────────────────────────

  def knowledge_transfer_plan(process)
    employee = process.employee
    user_msg = +"## Departing employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Last day: #{process.last_day}\n"
    user_msg << "Reason: #{process.reason}\n"

    if employee.department
      teammates = Employee.kept.where(department_id: employee.department_id).where.not(id: employee.id).limit(20)
      if teammates.any?
        user_msg << "\n## Team (potential KT recipients)\n"
        teammates.each { |t| user_msg << "  • id=#{t.id} #{t.full_name} (#{t.position&.name}, grade #{t.grade&.name})\n" }
      end
    end

    active_kpi = employee.kpi_assignments.where("period_end >= ?", 4.weeks.ago).includes(:kpi_metric).limit(15)
    if active_kpi.any?
      user_msg << "\n## Active responsibilities (KPI metrics)\n"
      active_kpi.each { |a| user_msg << "  • #{a.kpi_metric&.name} (target #{a.target}, weight #{a.weight})\n" }
    end

    chat([
      { role: "system", content: prompt_for("knowledge_transfer_plan") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("knowledge_transfer_plan"), task: "knowledge_transfer_plan", json: true)
  end

  def exit_interview_brief(process)
    employee = process.employee
    user_msg = +"## Departing employee\n"
    user_msg << "Name: #{employee.full_name}\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"
    user_msg << "Reason given: #{process.reason}\n"
    user_msg << "Manager: #{employee.manager&.full_name || '—'}\n"

    history = KpiEvaluation.joins(:kpi_assignment)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 26.weeks.ago..).order(evaluated_at: :desc).limit(30)
    if history.any?
      scores = history.map { |e| e.score.to_i }
      user_msg << "\n## KPI trend (26 weeks)\n"
      user_msg << "Latest: #{scores.first}%, avg: #{(scores.sum/scores.size.to_f).round(1)}%, trend: #{compute_trend(scores)}\n"
    end

    notes = employee.notes.order(created_at: :desc).limit(10)
    if notes.any?
      user_msg << "\n## Recent HR notes\n"
      notes.each { |n| user_msg << "  • #{n.created_at.to_date}: #{n.body.to_s.first(180)}\n" }
    end

    leaves_n = employee.leave_requests.where(state: %w[hr_approved active completed]).count
    user_msg << "\nTotal leaves taken: #{leaves_n}\n"

    chat([
      { role: "system", content: prompt_for("exit_interview_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("exit_interview_brief"), task: "exit_interview_brief", json: true)
  end

  def replacement_brief(process)
    employee = process.employee
    user_msg = +"## Departing employee (replacement context)\n"
    user_msg << "Position: #{employee.position&.name}\n"
    user_msg << "Grade: #{employee.grade&.name}\n"
    user_msg << "Department: #{employee.department&.name}\n"
    user_msg << "Tenure: #{tenure_months(employee)} months\n"

    active_kpi = employee.kpi_assignments.where("period_end >= ?", 4.weeks.ago).includes(:kpi_metric).limit(15)
    if active_kpi.any?
      user_msg << "\n## Responsibilities (active KPI metrics)\n"
      active_kpi.each { |a| user_msg << "  • #{a.kpi_metric&.name}\n" }
    end

    history = KpiEvaluation.joins(:kpi_assignment)
                .where(kpi_assignments: { employee_id: employee.id })
                .where(evaluated_at: 12.weeks.ago..).limit(20)
    if history.any?
      scores = history.map { |e| e.score.to_i }
      user_msg << "\nRecent average KPI: #{(scores.sum/scores.size.to_f).round(1)}%\n"
    end

    chat([
      { role: "system", content: prompt_for("replacement_brief") },
      { role: "user",   content: user_msg }
    ], max_tokens: output_tokens_for("replacement_brief"), task: "replacement_brief", json: true)
  end

  # ── Company Bootstrap ──────────────────────────────────────────────────────

  # Чат-ассистент: AI либо задаёт уточняющий вопрос, либо выдаёт полный пакет
  # словарей и схем для компании. История — массив [{role, content}] прошлых
  # реплик. user_message — новое сообщение HR.
  def company_bootstrap(company, user_message:, history: [])
    msgs = [ { role: "system", content: prompt_for("company_bootstrap") } ]
    msgs << { role: "user", content: company_bootstrap_context(company) }
    Array(history).each do |m|
      role    = m[:role] || m["role"]
      content = m[:content] || m["content"]
      msgs << { role: role, content: content.to_s } if role && content.present?
    end
    msgs << { role: "user", content: user_message.to_s.presence || "(пусто) Начинай с первого вопроса для уточнения." }

    chat(msgs, max_tokens: output_tokens_for("company_bootstrap"), task: "company_bootstrap", json: true)
  end

  def company_bootstrap_context(company)
    +"## Company\n" \
      "Name: #{company&.name}\n" \
      "Country: #{company&.country}\n" \
      "Default locale: #{company&.default_locale}\n"
  end

  # ── Dictionaries ───────────────────────────────────────────────────────────

  # Предложить набор записей для словаря с учётом контекста компании. Hint —
  # свободный текст пользователя про индустрию/что нужно.
  def dictionary_seed(dictionary, hint: "")
    chat([
      { role: "system", content: prompt_for("dictionary_seed") },
      { role: "user",   content: dictionary_context(dictionary, hint) }
    ], max_tokens: output_tokens_for("dictionary_seed"), task: "dictionary_seed", json: true)
  end

  def dictionary_context(dictionary, hint)
    company = dictionary.company
    existing = dictionary.entries.kept.map { |e| "  • #{e.key} = #{e.value}" }.join("\n")
    +"## Dictionary\n" \
      "Kind: #{dictionary.kind}\n" \
      "Code: #{dictionary.code}\n" \
      "Name: #{dictionary.name}\n" \
      "Description: #{dictionary.description}\n" \
      "Target model: #{dictionary.target_model || '—'}\n" \
      "Target scope: #{dictionary.target_scope || '—'}\n\n" \
      "## Company\n" \
      "Name: #{company&.name}\n" \
      "Country: #{company&.country}\n\n" \
      "## Existing entries (do NOT duplicate)\n" \
      "#{existing.presence || '(empty — propose initial set)'}\n\n" \
      "## User hint\n" \
      "#{hint.to_s.strip.presence || '(no hint — infer from company name and dictionary code)'}"
  end

  # ── Documents ──────────────────────────────────────────────────────────────

  # Сводка по документу. Если файл — картинка, шлём в OpenAI Vision API
  # (без OCR на сервере). Если PDF — извлекаем текст через pdf-reader.
  # Если ни то, ни другое — ok:false, UI покажет внятный fallback.
  def document_summary(document)
    return chat_document_vision(document, "document_summary") if document.file.image?
    chat_document_text(document, "document_summary")
  end

  # AI-извлечение полей. Image → vision (заменяет Tesseract+regex одним
  # запросом). PDF/text → стандартный путь по тексту.
  def document_extract_assist(document)
    return chat_document_vision(document, "document_extract_assist") if document.file.image?
    chat_document_text(document, "document_extract_assist")
  end

  private

  # Текстовый путь: PDF → pdf-reader → text → AI.
  def chat_document_text(document, task)
    text_result = Documents::TextExtractor.call(document.file.blob)
    text = text_result[:text].to_s.strip
    return no_text_error(text_result[:error]) if text.empty?

    chat([
      { role: "system", content: prompt_for(task) },
      { role: "user",   content: document_text_context(document, text) }
    ], max_tokens: output_tokens_for(task), task: task, json: true)
  end

  # Vision путь: image → base64 → OpenAI Vision. Заменяет связку OCR+regex
  # одним запросом — лучше работает на скриншотах/фото плохого качества.
  MAX_VISION_BYTES = 18 * 1024 * 1024
  def chat_document_vision(document, task)
    blob = document.file.blob
    data = blob.download
    return image_too_large_error(data.bytesize) if data.bytesize > MAX_VISION_BYTES

    data_url = "data:#{blob.content_type};base64,#{Base64.strict_encode64(data)}"
    chat([
      { role: "system", content: prompt_for(task) },
      { role: "user",   content: [
        { type: "text",      text: document_vision_context(document) },
        { type: "image_url", image_url: { url: data_url, detail: "high" } }
      ] }
    ], max_tokens: output_tokens_for(task), task: task, json: true)
  end

  def document_text_context(document, text)
    +"#{document_meta(document)}\n\n## Raw text (length=#{text.length})\n#{text.first(8000)}"
  end

  def document_vision_context(document)
    +"#{document_meta(document)}\n\n" \
      "The image attached is a scan or photo of this document. " \
      "Read all printed/handwritten text carefully, including stamps and seals. " \
      "Russian + Latin text both expected."
  end

  def document_meta(document)
    +"## Document\n" \
      "Type: #{document.document_type&.name} (extractor_kind=#{document.document_type&.extractor_kind})\n" \
      "Title: #{document.title.presence || document.display_title}\n" \
      "Owner: #{document.documentable.try(:full_name) || document.documentable_type}\n" \
      "Existing fields: number=#{document.number} issuer=#{document.issuer} " \
      "issued_at=#{document.issued_at} expires_at=#{document.expires_at}"
  end

  def no_text_error(reason)
    { ok: false, error: "no_text_for_ai:#{reason || 'empty'}",
      tokens: 0, input_tokens: 0, output_tokens: 0 }
  end

  def image_too_large_error(bytes)
    { ok: false, error: "image_too_large:#{bytes / 1024 / 1024}MB (max 18MB)",
      tokens: 0, input_tokens: 0, output_tokens: 0 }
  end

  def tenure_months(employee)
    return 0 unless employee&.hired_at
    ((Date.current - employee.hired_at).to_i / 30.0).round
  end

  def compute_trend(scores)
    return "no_data" if scores.size < 4
    half  = scores.size / 2
    early = scores.first(half).sum.to_f / half
    late  = scores.last(half).sum.to_f / half
    diff  = late - early
    return "rising"  if diff >  5
    return "falling" if diff < -5
    "flat"
  end

  def collect_team(scope_type, scope_id, requester)
    company = requester.employee&.company || Company.kept.first
    base = Employee.kept.where(company: company)
    case scope_type.to_s
    when "department" then base.where(department_id: scope_id).to_a
    when "manager_reports"
      requester.employee&.reports&.kept&.to_a || []
    else
      base.to_a
    end
  end

  # Возвращает payload последнего успешного analyze_resume (Hash) или nil.
  def last_analysis_for(applicant)
    run = AiRun.for_applicant(applicant).where(kind: "analyze_resume").successful.recent.first
    run&.payload
  end

  def round_context(round)
    a = round.job_applicant
    notes = round.notes.to_s.strip
    scores = round.competency_scores.to_h.map { |k, v| "  #{k}: #{v}/5" }.join("\n")

    <<~CTX
      Round: #{round.kind_label} (#{round.kind})
      Candidate: #{a&.full_name} (id=#{a&.id})
      Stage: #{a&.stage}
      Job opening: #{a&.job_opening&.title}

      Scorecard:
      #{scores.empty? ? "(нет оценок)" : scores}

      Overall score: #{round.overall_score || "не задан"}/100
      Interviewer recommendation: #{round.recommendation || "не указана"}

      Interviewer notes:
      #{notes.empty? ? "(нет)" : notes}

      Decision comment:
      #{round.decision_comment.to_s.strip}
    CTX
  end

  def applicant_context(a)
    <<~CTX
      Candidate: #{a.full_name}
      Position: #{a.current_position} · Company: #{a.current_company}
      Years of experience: #{a.years_of_experience}
      Stage: #{a.stage}
      Expected salary: #{a.expected_salary} #{a.currency}
      Source: #{a.source}
    CTX
  end

  def interview_context(applicant)
    rounds = applicant.interview_rounds.kept.where.not(competency_scores: {}).order(:scheduled_at)
    return "No completed interviews yet." if rounds.empty?

    rounds.map do |r|
      scores = r.competency_scores.map { |k, v| "#{k}=#{v}" }.join(", ")
      "[#{r.kind}] state=#{r.state} score=#{r.overall_score} rec=#{r.recommendation} scores={#{scores}} notes=#{r.notes&.first(140)}"
    end.join("\n")
  end

  # Низкоуровневый chat-запрос. Возвращает hash:
  #   { ok:, content:, tokens:, input_tokens:, output_tokens:, raw:, error: }
  # GPT-5/o-series API:
  #   • max_completion_tokens вместо legacy max_tokens
  #   • temperature только дефолтный (1.0) — не шлём
  #   • reasoning_effort: minimal — отключает скрытое reasoning, ускоряет
  #     ответ и снижает потребление completion-токенов.
  def chat(messages, max_tokens: 1500, json: false, task: nil)
    # Юзер может в Settings → AI поднять лимит выше дефолта (за качество)
    # или опустить (за экономию). reasoning_effort тоже настраиваемый.
    user_max         = setting.data["max_tokens_per_task"].to_i
    effective_tokens = user_max.positive? ? [ user_max, max_tokens ].max : max_tokens
    effort           = setting.data["reasoning_effort"].presence || "minimal"
    chosen_model     = task ? model_for(task) : model_key

    # gpt-5/o-series принимают ТОЛЬКО max_completion_tokens (max_tokens бросает
    # 400 "Unsupported parameter"). Все остальные провайдеры (OpenRouter / vLLM
    # / Anthropic-compat / Llama-серверы) ждут max_tokens. Поэтому шлём один
    # ключ в зависимости от семейства модели — нельзя слать оба.
    body = {
      model:    chosen_model,
      messages: messages
    }
    if chosen_model.match?(REASONING_MODELS_RE)
      body[:max_completion_tokens] = effective_tokens
      body[:reasoning_effort]      = effort
    else
      body[:max_tokens] = effective_tokens
    end
    body[:response_format] = { type: "json_object" } if json

    uri  = URI(api_url)
    req  = Net::HTTP::Post.new(uri, "Content-Type" => "application/json",
                                    "Authorization" => "Bearer #{api_key}")
    # OpenRouter рекомендует слать HTTP-Referer / X-Title — пробрасываем если
    # есть в настройках, не падаем если нет.
    if uri.host&.include?("openrouter")
      req["HTTP-Referer"] = setting.data["openrouter_referer"].to_s.presence || "https://hrms.local"
      req["X-Title"]      = setting.data["openrouter_app_title"].to_s.presence || "HRMS"
    end
    req.body = body.to_json

    # Поддержка HTTP-proxy из настроек (для регионов, где OpenAI заблокирован).
    # Формат: http://user:pass@proxy.example.com:8080
    proxy_url = setting.data["proxy_url"].to_s.strip
    http_class = if proxy_url.empty?
      Net::HTTP
    else
      pu = URI(proxy_url) rescue nil
      pu ? Net::HTTP::Proxy(pu.host, pu.port, pu.user, pu.password) : Net::HTTP
    end

    # Тяжёлые задачи (company_bootstrap, document_summary) с 4000+ токенов
    # вывода легко превышают 60с на gpt-5-nano. Скейлим лимит по effective_tokens:
    # 1 token ≈ 0.05с генерации в худшем случае, плюс 30с базы.
    timeout = (30 + (effective_tokens * 0.05)).clamp(60, 240).to_i
    resp = http_class.start(uri.hostname, uri.port, use_ssl: true, read_timeout: timeout, open_timeout: 15) { |http| http.request(req) }
    parsed = JSON.parse(resp.body) rescue { "error" => { "message" => "non-json response: #{resp.body.first(200)}" } }

    if resp.code.to_i.between?(200, 299)
      content   = parsed.dig("choices", 0, "message", "content").to_s
      finish    = parsed.dig("choices", 0, "finish_reason").to_s
      total     = parsed.dig("usage", "total_tokens").to_i
      input     = parsed.dig("usage", "prompt_tokens").to_i
      output    = parsed.dig("usage", "completion_tokens").to_i

      if content.strip.empty?
        suggestion = if model_key.include?("nano")
          "Модель nano сжигает токены на внутренний reasoning и не успевает выдать JSON. Переключитесь на gpt-5-mini в Настройки → AI — она надёжнее на структурных задачах и стоит копейки ($0.25/1M)."
        else
          "Увеличьте лимит токенов в Настройки → AI → Продвинутые → 'Лимит токенов на запрос' до 6000+, либо переключитесь на более крупную модель."
        end
        return {
          ok:            false,
          error:         "Модель вернула пустой ответ (finish_reason: #{finish}, потрачено #{total} токенов). #{suggestion}",
          tokens:        total, input_tokens: input, output_tokens: output, raw: ""
        }
      end

      payload = json ? safe_parse_json(content) : content
      { ok:            true,
        content:       payload,
        tokens:        total,
        input_tokens:  input,
        output_tokens: output,
        raw:           content,
        model:         chosen_model }
    else
      err = parsed.dig("error", "message") || resp.message
      { ok: false, error: err, status: resp.code, tokens: 0, input_tokens: 0, output_tokens: 0, model: chosen_model }
    end
  end

  def safe_parse_json(str)
    JSON.parse(str)
  rescue JSON::ParserError
    { "error" => "non-json", "raw" => str }
  end
end
