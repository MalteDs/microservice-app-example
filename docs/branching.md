# Branching Strategy

This project follows a branching model inspired by **GitFlow**.  
The goal is to maintain code quality, allow parallel development, and prepare for continuous integration and delivery.

---

##  Branches Overview

| Branch         | Purpose                                                              |
|----------------|----------------------------------------------------------------------|
| `main`         | Stable production-ready code. Only hotfixes or releases are merged here. |
| `dev`      | Integration branch for ongoing development. All features are merged here first. |
| `feature/*`    | Individual branches for new features or enhancements. Derived from `dev`. |
| `bugfix/*`     | Branches for non-critical bug fixes before release. Derived from `dev`. |
| `release/*`    | Preparing a new production release. Derived from `dev`, merged into `main` when stable. |
| `hotfix/*`     | Urgent fixes applied directly to `main` and back-merged into `dev`. |

---

##  Workflow

### Feature Development
1. Create a new branch from `develop`:
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/<feature-name>
    ```
2. Develop and commit changes using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

3. Push your branch and open a Pull Request to dev.

### Release Preparation

1. Create a release branch from dev:

```bash
git checkout develop
git checkout -b release/x.y.z
```

2. Apply version bumps, update documentation, run tests.

3. Merge into main and tag the release:

```bash
git checkout main
git merge release/x.y.z
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

4. Merge back into dev to keep it up to date.

### Hotfixes

1. Create a hotfix branch from main:

```bash
git checkout main
git checkout -b hotfix/<issue-name>
```


2. Fix the issue, commit, and merge back into main.

3. Tag the new version.

4. Merge the hotfix into dev as well.

## Branch Naming Convention

* Features: feature/<short-description>
Example: feature/login-page

* Bugfixes: bugfix/<short-description>
Example: bugfix/cors-error

* Releases: release/<version>
Example: release/1.2.0

* Hotfixes: hotfix/<short-description>
Example: hotfix/critical-auth-bug

## Commit Guidelines
We follow semantic commit messages for clarity and automatic changelog generation:

* feat: – new feature
* fix: – bug fix
* docs: – documentation only changes
* chore: – build, CI, or maintenance tasks
* refactor: – code refactoring without behavior change