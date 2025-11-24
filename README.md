# Community Todo (Quran Todo) — Code Review Practice

I am preparing this repository for the "Code Review Practice" onboarding task. Below I document the steps I followed and the artifacts I will submit so evaluators can review my work.

Overview
I built a small change in this codebase as the PR Creator, reviewed a PR as the PR Reviewer, revised my code based on feedback, and wrote a short reflection about the experience.

PR Creator checklist (what I do)
- Create a feature branch: git checkout -b feat/brief-description
- Make a focused change (one logical concern per PR)
- Add tests that cover the change and run them locally
- Write a clear PR description using the template below
- Push branch and open a PR in the chosen remote (GitHub/GitLab)

PR description template (use imperative style)
- Title: <imperative sentence summarizing the change>
- Summary: A short sentence explaining the purpose.
- Motivation: Why I made this change.
- What I changed: Bullet list of files/areas modified.
- Tests: What tests I added and how to run them.
- How to run locally: commands to reproduce.
- Checklist:
  - [ ] Tests pass locally
  - [ ] Code is linted
  - [ ] Sensitive files not committed (.gitignore checked)

PR Reviewer notes (format I use to give feedback)
- Start with a short summary of what I reviewed.
- For each comment include a label:
  - Nit: minor style/typo
  - Optional (or Consider): suggestion for improvement
  - FYI: informational note
- Focus areas: design, correctness, complexity, tests, naming, comments, consistency.
- End with a clear approval state or next steps.

Example feedback item
- Nit: Rename `foo` to `bar` for clarity.
- Optional: Consider splitting the long function into two for readability.
- FYI: This helper duplicates logic in utils/helper.dart.

Revision step (what I do after receiving feedback)
- Address reviewer comments in the same branch
- Update tests if needed
- Update PR description to reflect changes
- Push commits to the same PR for final review

Reflection template (short)
- What I learned as PR Creator:
- What I learned as PR Reviewer:
- Biggest challenge:
- How this improved the codebase:

Submission: how I submit the assignment

I follow these steps to submit the Code Review Practice task.

1) Prepare the branch and tests
- Create a focused branch:
  - git checkout -b feat/code-review-practice
- Run and confirm tests locally:
  - flutter test
- Ensure .gitignore is committed:
  - git add .gitignore
  - git commit -m "Add .gitignore to exclude sensitive files" || echo "already committed"

2) Remove any sensitive files already tracked (if present)
- Find tracked sensitive files:
  - git ls-files | grep -E "google-services.json|GoogleService-Info.plist|firebase_options.dart|.runtimeconfig.json|serviceAccount|key.properties|.jks|.keystore|.p12|.pem|.p8" || echo "no tracked sensitive files"
- Remove each tracked sensitive file from the index but keep locally:
  - git rm --cached path/to/file
  - git commit -m "Remove tracked sensitive file: path/to/file"

3) Commit and push the change
- Stage and commit code + tests:
  - git add .
  - git commit -m "Add <short imperative summary of change>"
- Push branch:
  - git push -u origin feat/code-review-practice

4) Open the PR (use this template in the PR description)
- Title: Add <imperative summary>
- Summary: A short sentence explaining the change.
- Motivation: Why I made this change.
- What I changed:
  - - list of files modified
- Tests:
  - - description of tests added and how to run them (flutter test)
- How to run locally:
  - - commands (flutter pub get; firebase emulators:start if needed; flutter run)
- Checklist:
  - [ ] Tests pass locally
  - [ ] Code is linted
  - [ ] Sensitive files not committed (.gitignore checked)

5) Attach reviewer feedback and reflection
- Add reviewer feedback as a markdown file or paste comments into the PR conversation.
- Add a short reflection (Reflection.md or a section in the PR) answering:
  - What I learned as PR Creator
  - What I learned as PR Reviewer
  - Biggest challenge
  - How this improved the codebase

6) Revise and finalize
- Address reviewer comments on the same branch.
- Update tests and PR description as needed.
- Push commits and request final review/approval.

What I attach for submission
- Link to the PR (or patch files)
- Reviewer feedback document (markdown)
- Link to the revised PR (or updated patch files)
- Reflection document (markdown)

Notes
- I do not include credentials or generated Firebase config in the repository. If any sensitive files were previously committed I remove them from the index before pushing.