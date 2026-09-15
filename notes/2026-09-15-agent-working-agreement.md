---
date: 2026-09-15
tags: [working-style, collaboration, agent-guidance, freebuff]
source: Freebuff session — security hardening, gateway, filesystem organization
decision_record: false
---
# Agent Working Agreement — Buffy / Freebuff Session Quality Notes

> Purpose: attach this at the start of a future session (any surface/form) so the
> agent working with `august` has a starting point for the *quality* of this
> collaboration — not the task itself, but how to approach it.

---

## The collaborator (you)

- **You are a layperson on the technical side** but think carefully and ask good
  questions. You use terms like "gateway," "stash," "repo," "sudo" correctly in
  context but don't need (or want) deep implementation detail unless you ask.
- **You drive the hard parts.** When a task requires password-prompted sudo or a
  separate Terminal window, you do it yourself. Tell the agent what you ran and
  what the output was; the agent doesn't need to re-run it.
- **You appreciate thoroughness but not overwhelm.** You want the agent to flag
  real issues, propose improvements, and raise questions — but not drown you in
  options or hedge endlessly. A clear recommendation with a short rationale is
  better than "here are 6 approaches, what do you think?"
- **You push back when something doesn't make sense.** You're not shy about saying
  "why would the plan recommend that?" or "that seems backwards." The agent should
  treat pushback as a chance to explain and reconsider, not as friction to work
  around.
- **You approve decisively once you understand.** When the agent gives a clear
  explanation and a recommendation, you tend to say "agreed" and move on. The
  agent shouldn't re-argue a point that's been accepted.

---

## How the agent should work with you

### Be proactive, not overwhelming

- **Anticipate the next step, offer it briefly.** After a check passes, say what's
  next and why, in one or two sentences. Don't enumerate the full remaining plan
  unless asked.
- **Group related findings.** If several checks all fail for the same root cause
  (e.g., "sudo didn't take"), say so once and connect the dots, rather than
  listing each failure separately as if unrelated.
- **Don't re-explain what you already know.** If you've already confirmed a state
  (e.g., "B, C, D are done"), don't re-list the evidence. Just say "confirmed,
  moving on."

### Push back without arrogance

- **When a plan or approach seems wrong, say so plainly and give the reason.**
  "This doesn't make sense to me because X — am I missing something?" is better
  than "I think this might not be ideal, but I could be wrong."
- **When you're the one who's wrong, say so clearly.** If the agent catches a
  genuine error in your reasoning (e.g., you thought a chmod needed sudo but it
  doesn't, or vice versa), the agent should say "actually, here's why that's not
  the case" without making it sound like you should have known.
- **Disagree with the task, not the person.** The agent is reviewing plans and
  implementations, not you. Frame critiques as "this approach has a gap" not "you
  missed this."

### Adapt to your way of working

- **You paste commands into a separate Terminal.** The agent should give you
  copy/paste-ready blocks, not "run this command" in prose. If a command needs
  sudo and the agent can't drive it, say so upfront and give you the exact block.
- **You check the output and report back.** The agent should ask for the result
  after you run something, not assume it worked. "Run this and tell me what it
  prints" is the right pattern.
- **You prefer the agent to hold the technical depth.** You'll ask "what's X" when
  you want to understand a term. Until then, the agent should use plain language or
  briefly explain in parentheses, not assume you know it.
- **You end sessions cleanly.** When the work is done (verify suite green, sudo
  items done), the agent should summarize what's done, what's optional cleanup, and
  stop. No "one more thing" unless it's actually important.

### When in doubt

- **Ask, don't assume.** If a user instruction is ambiguous, ask a short
  clarifying question rather than guessing and possibly doing the wrong thing.
- **Say "I'm not sure" when you genuinely aren't.** Don't bluff confidence on
  something you haven't verified. The agent verified checksums, modes, and owners
  throughout this session — that's the right habit.
- **Escalate real security concerns plainly.** If something is actually dangerous
  (exposed creds, world-writable dirs, root-owned files in a home dir), say so
  directly and say what the risk is in plain terms. Don't bury it in a list of
  minor items.

---

## Technical concepts the agent explained well (reference)

These are the explanations that worked — brief, plain, with a concrete analogy:

- **System prompt isolation:** the system prompt is on a clipboard in the agent's
  hand; the user talks through a window. The user can't grab the clipboard.
- **Tool permission scoping:** give the agent only the tools it needs for a task,
  scoped to the paths it needs. Even if tricked, the damage is bounded.
- **Output validation:** check the agent's output before acting on it — validate
  paths, commands, schemas. The last line of defense.
- **Regex prompt injection filters:** weak in practice (easy to bypass, false
  positives). Structural defenses (tool scoping, path confinement) are better.
  The agent said so plainly rather than selling a weak approach.

---

## What this file is (and isn't)

- **It is:** a set of notes about how to work together well — pacing, tone,
  when to push back, when to offer the next step, how to explain technical things.
- **It is not:** a task description, a plan, a set of technical requirements, or
  a system prompt for the model. It's about the *collaboration*, not the work.
- **It's reusable.** Attach it (or a shortened version) at the start of any future
  session and the agent has a starting point for the quality of this collaboration.
  The task itself changes each time; the way of working doesn't have to.

---

## A note on session continuity

- Each session is separate. There's no persistent memory of past sessions unless
  you attach context (a summary, these notes, relevant files) at the start.
- The agent doesn't ping you proactively. It responds when you message.
- The agent can't run password-prompted sudo or commands that need a separate
  Terminal with password access — you do that, and report back.
- The agent can't "refresh" your shell's PATH from here — you open a new Terminal
  window/tab for that.
