# Contributing & Branching Strategy

## Branch Model

```
main          ← stable releases only
develop       ← integration branch; all feature branches merge here
feature/*     ← one branch per epic/ticket
```

## Branch Naming

```
feature/HABIT-{ticket-number}-{short-description}
```

Examples:
- `feature/HABIT-001-project-foundation`
- `feature/HABIT-010-data-layer`
- `feature/HABIT-020-theming`

## Workflow

1. Always branch off `develop`:
   ```
   git checkout develop
   git pull origin develop
   git checkout -b feature/HABIT-XXX-description
   ```

2. Commit often with conventional commit messages:
   ```
   feat(HABIT-XXX): add streak calculation engine
   fix(HABIT-XXX): correct grace period boundary condition
   test(HABIT-XXX): add unit tests for streak reset logic
   refactor(HABIT-XXX): extract DAO into repository pattern
   ```

3. When epic is complete, merge back to `develop`:
   ```
   git checkout develop
   git merge --no-ff feature/HABIT-XXX-description
   ```

## Commit Message Format

```
<type>(HABIT-XXX): <short description>

[optional body]
```

Types: `feat`, `fix`, `test`, `refactor`, `style`, `docs`, `chore`

## Dependency Rules

- Never merge a feature branch into `main` directly
- Always merge `develop` into your feature branch before merging back (keep up to date)
- Epics with dependencies must wait for their upstream epic to land on `develop` before starting
