---
name: setup
description: Bootstrap a repository by understanding its stack and generating a concise AGENTS.md with the project's real conventions. Use when setting up OpenCode instructions for a repo.
disable-model-invocation: true
---

# Setup

Set up the OpenCode instructions for the current repository.

## 1. Explore the project

Before writing anything:

- Read the root directory listing.
- Check for package.json, pyproject.toml, Cargo.toml, go.mod, pom.xml, build.gradle, Makefile, docker-compose.yml, Dockerfile, CI workflows, and similar project files.
- Identify the language, framework, test runner, linter, formatter, build tool, and CI setup.
- Read README.md if present for context only.
- Inspect the directory structure.
- Read a few key source files to understand the architecture and existing patterns.

Do not modify anything during exploration.

## 2. Generate AGENTS.md

Write `AGENTS.md` at the project root.

The file must be:

- In English
- Concise
- Based only on information verified from the repository
- Written for a developer using OpenCode
- Organized with clear headings

Use only sections that contain real information:

```text
# Project Name

One-line description.

## Stack

Language version, framework, important libraries, database, infrastructure.

## Architecture

Short description of the structure and important boundaries.

## Commands

Install, run, test, lint, format, and build commands.

## Environment

Required environment variable names and the location of any example file.

## Conventions

Non-obvious project-specific conventions.
```

Rules:

- Do not invent information.
- Do not copy the README.
- Do not add generic AI guidance.
- Do not add filler such as "This document provides..." or "Feel free to...".
- Do not add sections with no useful content.
- Keep sentences short.

## 3. Protect credentials

Check whether the repository already has an OpenCode configuration.

Do not expose or copy secret values.

OpenCode already denies `.env` reads by default. If the project has additional credential patterns that need protection, describe them to the user rather than weakening the global credential protection.

Never print secret values.

## 4. Confirm

After writing `AGENTS.md`, report briefly:

- Which sections were included.
- Which project files were used to infer the instructions.
- Any information that could not be verified.
