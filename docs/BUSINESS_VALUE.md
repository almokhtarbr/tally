# Business Value — Why SaaS Companies Need This

Tally isn't a dashboard that shows pretty charts. It answers specific business questions that directly affect revenue.

---

## The 5 Questions Every SaaS Founder Asks

### 1. "Are my new signups actually becoming customers?"

**The problem:** You spend money on ads, SEO, content to get signups. But a signup is worthless if they never use the product. Most SaaS apps lose 60-80% of signups in the first week.

**What to track:**
```
new-user → first-project-created → first-quote-created → first-invoice-sent → subscription-upgraded
```

**What Tally shows:** A conversion funnel. Out of 100 signups this month, how many created a project? How many sent their first invoice? Where exactly are people dropping off?

**Business decision:** If 80% create a project but only 10% send an invoice, your invoice feature is confusing or buried. Fix that one screen and you 8x your activation rate.

---

### 2. "Who is about to cancel?"

**The problem:** Churn kills SaaS. A customer who cancels after 3 months cost you money (acquisition + support) and gave you nothing back. By the time they cancel, it's too late.

**What to track:**
- `login` — frequency and recency
- Feature usage: `project-created`, `quote-created`, `invoice-sent`
- `subscription-update` — downgrade events

**What Tally shows:** User activity timelines. You can see that "Company X" logged in 15 times in January, 3 times in February, and 0 times so far in March. They're gone.

**Business decision:** Send an email or call them NOW, before they hit the cancel button. "Hey, noticed you haven't been around — anything we can help with?" costs you 5 minutes. Losing a $200/mo customer costs you $2,400/year.

---

### 3. "What features should I build next?"

**The problem:** Your backlog has 50 feature requests. Your dev team has bandwidth for 3 this quarter. How do you pick?

**What to track:**
- Every major feature interaction: `search`, `export-pdf`, `user-invited`, `quote-duplicated`, `bulk-edit`
- `settings-changed` — what settings do people actually touch?

**What Tally shows:** A leaderboard of what users actually DO. Not what they say they want in surveys — what they actually click.

**Business decision:** If `search` is used 10x more than `export-pdf`, and someone requests "better export," you know to deprioritize it. Build what people use, not what they ask for.

---

### 4. "Is my pricing change working?"

**The problem:** You changed pricing last month. Revenue looks the same. Is it working? Is it too early to tell? Are new customers converting at a higher rate but old ones churning?

**What to track:**
- `subscription-update` with properties: `{ plan: "premium", mrr: 99, previous_plan: "starter" }`
- `trial-started`, `trial-ended`, `trial-converted`
- `subscription-cancelled` with property: `{ reason: "too expensive" }`

**What Tally shows:** Before/after comparison. Trial-to-paid conversion rate was 12% before the change, now it's 18%. But cancellations from "starter" plan increased 30%. Net impact: positive but you're losing small customers.

**Business decision:** Keep the new pricing but add a cheaper entry plan to stop small customer churn. You'd never know this from looking at total revenue alone.

---

### 5. "Which customers are my best customers?"

**The problem:** You treat all customers the same. But some generate 10x more revenue, refer other customers, and never contact support. Others pay minimum and file tickets every week.

**What to track:**
- Identify users with: `plan`, `mrr`, `company_size`, `industry`, `signup_source`
- Track engagement: event frequency per user

**What Tally shows:** User profiles ranked by activity. "Company A" on the enterprise plan uses every feature daily. "Company B" on the same plan hasn't logged in this month.

**Business decision:** Company A gets a case study, a referral ask, and early access to new features. Company B gets a check-in call before they churn. Without data, you'd treat them identically.

---

## What This Means for Tally as a Product

### Target customer
Small-to-mid SaaS companies (5-500 employees) who:
- Currently use Mixpanel/Amplitude and are overpaying
- OR use nothing and are flying blind
- Don't need funnels, cohorts, A/B testing — just answers to the 5 questions above

### Why they'd pay
| Plan | Price | For who |
|---|---|---|
| Free | $0 | 1 project, 10K events/month, 30-day retention |
| Pro | $29/mo | 5 projects, 1M events/month, 1-year retention |
| Business | $99/mo | Unlimited projects, 10M events/month, unlimited retention |

Compared to Mixpanel ($999/mo for similar volume), this is a no-brainer.

### Why they'd choose Tally over PostHog (free, open source)
- PostHog is complex to self-host and configure
- PostHog has 100+ features, most of which you'll never use
- Tally is simple: track events, see trends, understand users. That's it.
- Tally takes 5 minutes to set up. PostHog takes a weekend.

---

## Real Event Schema for a SaaS App

Here's what a real customer (like C-Cube) would actually track:

### Events
| Event | When | Properties | Business Question |
|---|---|---|---|
| `user-signup` | New account created | `source`, `plan`, `referral` | Where do customers come from? |
| `onboarding-completed` | Finished setup wizard | `steps_completed`, `duration_minutes` | Is onboarding too long? |
| `project-created` | First core action | `template_used` | Are users activating? |
| `feature-used` | Any key feature | `feature_name`, `duration` | What features matter? |
| `invite-sent` | Invited a teammate | `role` | Is the product going viral inside companies? |
| `subscription-started` | Converted to paid | `plan`, `mrr`, `trial_days` | What converts? |
| `subscription-changed` | Up/downgrade | `from_plan`, `to_plan`, `mrr_change` | Are upgrades > downgrades? |
| `subscription-cancelled` | Churned | `reason`, `months_active`, `mrr_lost` | Why do people leave? |
| `support-ticket-created` | Filed a ticket | `category`, `priority` | What causes friction? |
| `export-used` | Exported data | `format`, `record_count` | Who's extracting data to leave? |

### User Properties
| Property | Example | Business Question |
|---|---|---|
| `plan` | `"premium"` | Revenue segmentation |
| `mrr` | `99` | Customer value |
| `company_size` | `"11-50"` | Ideal customer profile |
| `industry` | `"construction"` | Market focus |
| `signup_date` | `"2026-01-15"` | Cohort analysis |
| `last_active` | `"2026-03-14"` | Churn risk |
| `features_used_count` | `7` | Engagement depth |

---

## The Pitch (30 seconds)

> "You're paying $1000/month for Mixpanel to track 10 events. Tally does the same thing for $29. It answers 5 questions: Are signups activating? Who's about to churn? What features matter? Is your pricing working? Who are your best customers? Takes 5 minutes to set up. No PhD in analytics required."
