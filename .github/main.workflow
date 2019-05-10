workflow "push" {
  on = "push"
  resolves = ["dist:nuget", "dist:github-release", "docs:publish"]
}

workflow "everyday" {
  on = "schedule(59 14 * * *)"
  resolves = ["dist:nuget"]
}

action "docs:build" {
  uses = "dahlia/actions/docfx@master"

  needs = "dist:pack"
  # dotnet build & msbuild may occur error if both is running at a time,
  # so in order to wait until one is finished add dist:pack action as
  # a dependency of this action.

  env = {
    MSBUILD_PROJECT = "Libplanet"
  }
  args = ["Docs/docfx.json"]
}

action "docs:publish" {
  uses = "docker://alpine/git:latest"
  needs = "docs:build"
  secrets = [
    # GHPAGES_SSH_KEY has to contain a base64-encoded private key without
    # new lines:
    #   base64 -w0 < ssh_key_file
    # The key has to be also registered as a deploy key of the repository,
    # and be allowed write access.
    "GHPAGES_SSH_KEY"
  ]
  runs = ["Docs/publish.sh"]
}

action "dist:version" {
  uses = "docker://mcr.microsoft.com/powershell:latest"
  args = [".github/bin/dist-version.ps1"]
}

action "dist:pack" {
  uses = "docker://mcr.microsoft.com/dotnet/core/sdk:2.2"
  needs = "dist:version"
  runs = [".github/bin/dist-pack.sh"]
}

action "dist:release-note" {
  uses = "docker://alpine:3.9"
  needs = "dist:version"
  runs = [
    ".github/bin/dist-release-note.sh",
    "CHANGES.md",
    "obj/release_note.txt"
  ]
}

action "dist:nuget" {
  uses = "docker://mcr.microsoft.com/dotnet/core/sdk:2.2"
  needs = ["dist:pack", "dist:release-note"]
  runs = [".github/bin/dist-nuget.sh"]
  secrets = [
    "NUGET_API_KEY"
  ]
}

action "dist:github-release" {
  uses = "docker://alpine:3.9"
  needs = ["dist:pack", "dist:release-note"]
  runs = [".github/bin/dist-github-release.sh"]
  secrets = [
    "GITHUB_TOKEN"
  ]
}
