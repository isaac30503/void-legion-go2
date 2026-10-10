---
name: explicit-recipe
description: The reinstall recipe must be 100 % explicit, without steps that have to be inferred
metadata:
  type: feedback
---

The recipe (`void-legion-go2.md` here, `docs/void-legion-go2.md` in the repository; `void-ideapad-100.md` on the IdeaPad) has to be followable to the letter to reinstall the
same system: each thing applied with its exact command, in its step and in the right order, with
the check next to it, and the files it needs backed up on the disk (in the repository: in git, or as an asset
of the GitHub Release).

**Why:** the user asked for it explicitly (2026-10-02): "no deja de ser una receta" ("it is still a recipe"); they do not want
to have to infer anything when reinstalling.

**How to apply:** when changing something on the machine, add to the recipe the concrete command (not only
the explanation), back up what is downloaded from the internet when possible (e.g. Orchis in tar.gz) and
add its line to the *Final check* (*Verification*). See [[answer-in-spanish]].
