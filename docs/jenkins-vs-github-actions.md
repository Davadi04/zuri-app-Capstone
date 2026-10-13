# Jenkins vs GitHub Actions — for Zuri Market

The brief asks for a comparison, not a working Jenkins pipeline. This is that comparison, with a conclusion grounded in Zuri Market's actual situation: a 3-developer team with no dedicated platform or DevOps engineer, until this project.

## Comparison

| Criterion | Jenkins | GitHub Actions | For Zuri |
|---|---|---|---|
| **Who runs it** | You install, patch, and back up the server and build agents yourself | GitHub runs and maintains it; you only write the pipeline | **Actions** — Zuri has no platform team to own a Jenkins server |
| **Time to first pipeline** | Install, plugins, credentials, webhooks — real setup effort | A YAML file in the repo works on the first push | **Actions** |
| **Git integration** | Via plugins and webhooks, configured by hand | Native — pull request checks, required status checks, built-in secrets | **Actions** |
| **Pipeline as code** | A `Jenkinsfile`, plus UI/plugin configuration that often lives outside the repo | YAML in the repo only, nothing hidden in a UI | **Actions**, more consistently code-as-config |
| **Ecosystem** | Very large plugin ecosystem; every plugin is something to patch and secure | A large marketplace of actions; real supply-chain risk (see below) | Tie — both carry third-party risk |
| **Cost** | Server cost plus the time to maintain it | Free minutes for public repos; this project used that free tier end to end | **Actions**, at Zuri's current scale |
| **Ceiling** | Very strong for complex, on-premises, or highly customised pipelines | Enough for most teams; self-hosted runners exist if ever needed | Revisit only if Zuri's needs grow significantly |

## What this project actually proved about the tradeoffs

This isn't a theoretical comparison — two real things happened while building this pipeline that are directly relevant to the "ecosystem risk" row above:

**A real supply-chain compromise, caught and fixed.** In 2026, the `SonarSource/sonarqube-scan-action` GitHub Action was disclosed as vulnerable to command injection (CVE-2025-58178, and a second injection issue patched in v6.0.0). Separately, `aquasecurity/trivy-action` suffered an actual incident on 19 March 2026, where a threat actor force-pushed 75 of 76 version tags to point at credential-stealing malware. Both actions in this pipeline are pinned to an exact 40-character commit SHA, not a mutable version tag, specifically because of this. This is the real cost of a marketplace ecosystem: it's genuinely useful, but every third-party action is something you have to actively defend against, exactly the "plugin to secure" problem Jenkins has too, just under a different name.

**No server to maintain, meaningfully.** This pipeline runs lint, tests, a SonarQube quality gate, a Trivy scan, Docker builds, pushes to a registry, and a full Kubernetes deployment, entirely on GitHub-hosted runners. At no point was a build server provisioned, patched, or backed up. For a team with no dedicated DevOps engineer until this project, that absence of infrastructure to own is the single biggest practical difference from Jenkins.

## Conclusion

Zuri Market is a three-developer team with no dedicated operations staff and a codebase already hosted on GitHub. The managed, in-repo, pull-request-integrated model of GitHub Actions fits that reality directly: no server to install or patch, pipeline-as-code from the first commit, and native PR gating that makes "everyone pushes to `main`" (Zuri's actual incident) structurally harder to repeat.

Jenkins becomes the better choice only if Zuri's needs grow in a specific direction: heavy customisation GitHub Actions can't express, a requirement to build entirely on-premises, or a team large enough to justify maintaining dedicated CI infrastructure. None of those apply today.