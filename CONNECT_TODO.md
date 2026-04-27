# Jido Connect Connector Roadmap

## Overview

`jido_connect` should become a broad connector catalog for Jido agents: provider
packages that compile Spark DSL declarations into generated Jido actions,
sensors, and plugins while keeping auth, credentials, scopes, webhooks, and
provider API behavior behind stable runtime contracts.

This list is seeded from Lindy's public integrations catalog, with their "Most
Popular" section treated as the top popularity signal:

1. Google Sheets
2. Gmail
3. Slack
4. Google Drive
5. HubSpot
6. Calendly
7. Airtable
8. Salesforce

After those, the ranking is a pragmatic build order based on likely Jido agent
utility, category breadth, OAuth complexity reuse, and how much each connector
helps prove reusable core abstractions.

## Ranking Principles

- Build high-frequency agent workflows first: email, files, spreadsheets, CRM,
  calendar, chat, and support.
- Prefer connector families where one auth/client foundation unlocks multiple
  packages, such as Google, Microsoft, Atlassian, and Salesforce ecosystems.
- Keep provider packages thin: DSL, auth helpers, client boundary, handlers,
  webhook helpers, tests.
- Push reusable behavior down into `jido_connect`: OAuth, app installation
  flows, scope resolution, webhooks, pagination, rate limits, error taxonomy,
  availability checks, and local demo harnesses.
- Every connector should ship with generated Jido actions, generated sensors
  where useful, plugin availability, docs, and local test/demo support.

## Status Legend

- `seeded`: exists now and is used to harden the architecture.
- `next`: should be built soon.
- `planned`: important, but after the first connector families are stable.
- `later`: useful breadth once the core package is mature.

## Ranked Connector Build List

| Rank | Package | Provider | Status | Auth shape | First actions | First triggers/sensors | Why this rank |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `jido_connect_google_sheets` | Google Sheets | next | OAuth2 user, service account later | read sheet, append row, update row, search rows, create sheet | new row poll | Lindy top popular item; proves tabular data workflows. |
| 2 | `jido_connect_gmail` | Gmail | next | OAuth2 user | list messages, get message, send email, draft reply, add label | new email poll, label email poll | Core personal assistant workflow; proves restricted scopes and sensitive auth UX. |
| 3 | `jido_connect_slack` | Slack | seeded | OAuth2 bot | list channels, post message | message/event webhook later | Already started; keep expanding as collaboration reference connector. |
| 4 | `jido_connect_google_drive` | Google Drive | next | OAuth2 user, service account later | search files, get file metadata, download/export file, upload file, create folder | new file poll | File context is essential for agents; shares Google auth foundation. |
| 5 | `jido_connect_hubspot` | HubSpot | next | OAuth2 app, private app token | search contacts, create/update contact, create note, create deal | new contact poll, deal stage change poll | High-value sales automation; good CRM reference model. |
| 6 | `jido_connect_calendly` | Calendly | next | OAuth2 user, webhook signing | list events, get event, cancel event | invitee created webhook, invitee canceled webhook | Clean scheduling connector; proves webhooks and event normalization. |
| 7 | `jido_connect_airtable` | Airtable | next | OAuth2, personal access token | list records, get record, create/update record, delete record | changed records poll | Flexible database-like app; useful for many agent workflows. |
| 8 | `jido_connect_salesforce` | Salesforce | planned | OAuth2, refresh token, connected app | query SOQL, get record, create/update lead, create task | record changed poll/webhook later | Enterprise CRM anchor; more complex auth and schemas. |
| 9 | `jido_connect_google_calendar` | Google Calendar | next | OAuth2 user | list events, create event, update event, find availability | upcoming event poll, event changed poll | Natural pair with Gmail and assistant workflows. |
| 10 | `jido_connect_microsoft_outlook` | Microsoft Outlook Mail | planned | OAuth2 Microsoft Graph | list messages, get message, send email, create draft | new email poll | Mirrors Gmail for Microsoft tenants. |
| 11 | `jido_connect_microsoft_calendar` | Microsoft Calendar | planned | OAuth2 Microsoft Graph | list events, create/update event, find availability | event changed poll | Completes Microsoft assistant workflow. |
| 12 | `jido_connect_microsoft_onedrive` | OneDrive | planned | OAuth2 Microsoft Graph | search files, download file, upload file | new file poll | Complements Outlook and Microsoft 365 file workflows. |
| 13 | `jido_connect_zendesk` | Zendesk | planned | OAuth2, API token | search tickets, create ticket, update ticket, add comment | new ticket poll, ticket updated webhook | Strong support category anchor from Lindy's support list. |
| 14 | `jido_connect_intercom` | Intercom | planned | OAuth2, access token | search contacts, create conversation, reply to conversation | conversation created webhook | Support and sales assistant workflows. |
| 15 | `jido_connect_freshdesk` | Freshdesk | planned | API key, OAuth later | list tickets, create ticket, update ticket, add note | new ticket poll | Support breadth; simpler API-key connector. |
| 16 | `jido_connect_jira` | Jira / Jira Service Management | planned | OAuth2, API token | search issues, create issue, update issue, add comment | issue created/updated webhook | Project/support overlap; important enterprise workflow. |
| 17 | `jido_connect_linear` | Linear | planned | OAuth2, API key | search issues, create issue, update issue, add comment | issue created/updated webhook | Modern product/dev workflow; clean API. |
| 18 | `jido_connect_asana` | Asana | planned | OAuth2, personal access token | list tasks, create task, update task, add comment | task changed webhook | Common task management automation. |
| 19 | `jido_connect_trello` | Trello | planned | OAuth1/API key token | list cards, create card, move card, comment | card changed webhook | Lightweight project workflow. |
| 20 | `jido_connect_monday` | monday.com | planned | API token, OAuth later | list boards, create item, update column value | item changed webhook/poll | Appears in Lindy sales list; broad ops use. |
| 21 | `jido_connect_notion` | Notion | planned | OAuth2, internal integration token | search pages, read page, create page, update database item | database item changed poll | High agent utility for knowledge/workspace data. |
| 22 | `jido_connect_shopify` | Shopify | planned | OAuth2 app, admin API token | list orders, get order, update order, create customer | order created webhook | Commerce anchor; Lindy lists Shopify OAuth. |
| 23 | `jido_connect_stripe` | Stripe | planned | API key, restricted key, webhook signing | list customers, create customer, create invoice, get payment | payment succeeded webhook | Payments/revenue operations. |
| 24 | `jido_connect_bigcommerce` | BigCommerce | later | OAuth2/API token | list orders, get order, update order | order webhook | Commerce breadth; Lindy visible in catalog. |
| 25 | `jido_connect_github` | GitHub | seeded | OAuth2 user, GitHub App installation | list issues, create issue | new issues poll | Existing dev-work connector and GitHub App auth reference. |
| 26 | `jido_connect_gitlab` | GitLab | planned | OAuth2, personal access token | list issues, create issue, comment, list merge requests | issue/MR webhook | Natural follow-on to GitHub. |
| 27 | `jido_connect_azure_devops` | Azure DevOps | planned | OAuth2/PAT | list work items, create work item, update work item | work item updated webhook | Enterprise dev workflow; visible in Lindy catalog. |
| 28 | `jido_connect_discord` | Discord | later | OAuth2 bot | list channels, send message | message webhook/gateway later | Collaboration breadth after Slack/Teams. |
| 29 | `jido_connect_zoom` | Zoom | planned | OAuth2 server-to-server/user | list meetings, create meeting, get recording | meeting ended webhook, recording ready webhook | Meetings and assistant workflows. |
| 30 | `jido_connect_google_meet` | Google Meet | later | OAuth2 user | create conference via Calendar, get conference records | meeting artifact poll | Likely through Calendar first; split later if needed. |
| 31 | `jido_connect_youtube` | YouTube Data API | later | OAuth2/API key | search videos, get video, list channel videos | new channel video poll | Lindy sales list includes YouTube Data API. |
| 32 | `jido_connect_typeform` | Typeform | planned | OAuth2, personal token, webhook signing | list forms, get responses | new response webhook | Forms are high-value lead/support triggers. |
| 33 | `jido_connect_google_forms` | Google Forms | later | OAuth2 user | list forms, get responses | new response poll | Complements Google family. |
| 34 | `jido_connect_mailchimp` | Mailchimp | later | OAuth2/API key | list audiences, add/update member, create campaign | subscriber event webhook | Marketing automation category. |
| 35 | `jido_connect_activecampaign` | ActiveCampaign | later | API key | search contacts, create/update contact, add tag | contact updated webhook/poll | Marketing/sales automation. |
| 36 | `jido_connect_zoho_crm` | Zoho CRM | later | OAuth2 | search leads, create lead, update contact | record changed poll | Lindy marketing list includes Zoho CRM. |
| 37 | `jido_connect_zoho_desk` | Zoho Desk | later | OAuth2 | list tickets, create ticket, update ticket | ticket changed poll | Lindy support list includes Zoho Desk. |
| 38 | `jido_connect_sftp` | SFTP | planned | password, key-based auth | list files, download file, upload file, move file | new file poll | Lindy lists password and key SFTP; proves non-HTTP credentials. |
| 39 | `jido_connect_http` | Generic HTTP | planned | API key, bearer token, basic auth | request, get JSON, post JSON | webhook receive helper | Lets hosts cover long-tail APIs without custom package first. |
| 40 | `jido_connect_webhook` | Generic Webhook | planned | shared secret/HMAC | normalize inbound payload | inbound webhook | Important for long-tail trigger coverage and demo harness. |

## Suggested Build Waves

### Wave 1: Google And Assistant Core

- Google OAuth foundation
- Google Sheets
- Gmail
- Google Drive
- Google Calendar

This wave proves shared OAuth app setup, sensitive scopes, refresh handling,
cross-package auth reuse, and high-frequency assistant workflows.

### Wave 2: Sales And CRM

- HubSpot
- Airtable
- Salesforce
- Calendly

This wave proves CRM object models, search/list/create/update patterns,
webhook/poll parity, and richer schema metadata.

### Wave 3: Support And Work Management

- Zendesk
- Intercom
- Freshdesk
- Jira
- Linear

This wave proves ticket/issue normalization, threaded comments, assignee/status
models, and webhook dedupe at higher volume.

### Wave 4: Commerce, Payments, And Protocol Connectors

- Shopify
- Stripe
- SFTP
- Generic HTTP
- Generic Webhook

This wave rounds out revenue operations and long-tail connector support.

## Core Work Needed Before Scaling Past 10 Connectors

- Shared OAuth client helpers with provider-specific overrides.
- Standard pagination and cursor helpers.
- Standard rate-limit and retry metadata in provider errors.
- Dynamic scope requirements at action and input level.
- Connection health checks and availability diagnostics.
- Webhook verification helpers with replay/dedupe contracts.
- Provider test harness helpers for Req stubs, OAuth callbacks, app manifests,
  and webhook fixtures.
- Demo UI that can host many integrations without custom pages per provider.

