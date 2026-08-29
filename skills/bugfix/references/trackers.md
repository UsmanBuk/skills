# Pulling a complete ticket

The intake phase needs the whole ticket, not the summary: the last comment on a busy
ticket often narrows or flips the ask, and screenshots carry the reporter's actual
scenario. Whatever the source, `ticket.md` should hold the verbatim text of the
description and every substantive comment, the list of attachments (with what you saw in
each), links to related tickets, and then your restatement.

Credentials live in the project's `CLAUDE.local.md`, `.env`, or the environment — read
them from there; never echo a token into the conversation or a `$WORK` file. If no
credential is available, ask the user to paste the ticket and its comments rather than
guessing at the content.

## Jira (`PROJ-1234`)

Prefer the Atlassian MCP when it is connected: `getJiraIssue` with the key returns
fields, description, and comments; follow `issuelinks` and `parent` for related tickets;
`getJiraIssueRemoteIssueLinks` for external links. Attachments come back as URLs — fetch
images so you can look at them.

REST fallback (cloud), basic auth `email:api-token`:

```bash
curl -sS -u "$JIRA_EMAIL:$JIRA_TOKEN" \
  "https://<site>.atlassian.net/rest/api/3/issue/PROJ-1234?fields=summary,description,status,priority,issuetype,comment,attachment,issuelinks,parent,labels"
```

`description` and comment bodies are Atlassian Document Format (nested JSON); flatten
the `text` nodes. `comment.comments` is paginated (`maxResults`, `startAt`) — loop until
`total` is reached. Attachment `content` URLs need the same auth header.

## Asana (task gid or URL)

REST with a personal access token, `Authorization: Bearer $ASANA_PAT`:

```bash
B=https://app.asana.com/api/1.0
curl -sS -H "Authorization: Bearer $ASANA_PAT" \
  "$B/tasks/<gid>?opt_fields=name,notes,completed,assignee.name,custom_fields.name,custom_fields.display_value,memberships.section.name,parent.name,permalink_url"
curl -sS -H "Authorization: Bearer $ASANA_PAT" "$B/tasks/<gid>/attachments?opt_fields=name,download_url,host"
curl -sS -H "Authorization: Bearer $ASANA_PAT" \
  "$B/tasks/<gid>/stories?opt_fields=type,created_by.name,created_at,text&limit=100"
```

Stories mix comments (`type: comment`) with system events; keep the comments. The
response carries `next_page.uri` when there are more — request that URI verbatim until
it is null. Busy tickets exceed 100 stories and the ones that matter are at the end.
The gid is the long number in the task URL (`/0/<project>/<gid>`). An `ID-####` style
reference is usually a custom field on the board, not the gid — search the section's
tasks for it.

## GitHub issue (`#42` or URL)

```bash
gh issue view 42 --repo <owner>/<repo> --comments \
  --json number,title,body,state,labels,comments,assignees,url
```

Image attachments appear as URLs in the body/comments; fetch them. Linked PRs and
"fixes #" references are worth reading — someone may have tried already.

## Pasted or ad-hoc report

Treat the user's description as the ticket. Restate it in `ticket.md` — expected vs
actual, the exact steps, the environment — and confirm the restatement with the user
before Phase 2 if anything material was inferred. Ask for logs, screenshots, or the
failing input if they exist; a report without a concrete scenario is hard to reproduce
and easy to fix wrong.

## Other trackers

Use whichever MCP or CLI is connected for it (Linear, Shortcut, Azure Boards…) and aim
for the same completeness: description, all comments in order, attachments, links. If
nothing is connected, ask for a paste.
