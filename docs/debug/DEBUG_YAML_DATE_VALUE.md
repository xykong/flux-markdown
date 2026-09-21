---
title: "YAML Date Value Debug"
date: 2025-08-12
tags:
  - yaml-frontmatter
  - date
  - renderer
  - debug
---

# YAML Date Value Debug

## Symptom

A YAML date value does not show in the front matter table.

## Reproduction

1. Open a Markdown file with a YAML front matter block.
2. Set `date: 2024-01-01` in the block.
3. View the front matter table.

## Initial State

The renderer uses `js-yaml` to parse the block.
The table renderer treats each object value as a nested object.

## Hypothesis

`js-yaml` converts a YAML date value to a `Date` object.
The table renderer treats this `Date` object as a nested YAML object.
A `Date` object has no enumerable table entries.
The renderer creates an empty nested table in the value cell.

## Test

The test checks that a date value shows its ISO date text.

## Result

The test failed before the code change.
The table text contained `date` but not `2024-01-01`.

The renderer now formats a `Date` object as an ISO date.
The test passes after the code change.
The cause was value conversion, not a color rule.
