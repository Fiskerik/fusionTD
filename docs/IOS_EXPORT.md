# Build Elemental TD for TestFlight from Windows

Codemagic runs Godot and Xcode on a hosted Mac. The workflow in `codemagic.yaml` uses Godot 4.4.1 and Xcode 26.4, runs the game’s tests, builds a signed iOS archive, and uploads it to App Store Connect. Codemagic offers this Xcode version on its Mac mini M2 runners, and the project's iOS 15 deployment target meets Apple's current minimum. [Codemagic Xcode 26.4 image](https://docs.codemagic.io/specs-macos/xcode-26-4/) · [Apple upload requirements](https://developer.apple.com/news/upcoming-requirements/)

## 1. Register the app with Apple

1. Sign in to [Apple Developer](https://developer.apple.com/account/). In **Certificates, Identifiers & Profiles → Identifiers**, register an explicit App ID using your own bundle ID, for example `com.yourcompany.elementaltd`. Copy the 10-character **Team ID** from your membership details.
2. In [App Store Connect](https://appstoreconnect.apple.com/), go to **Apps → + → New App**. Choose **iOS**, enter the game’s name and a SKU such as `elemental-td-ios`, and select the bundle ID you just registered. [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
3. In `codemagic.yaml`, replace `com.example.elementaltd` in **environment → ios_signing → bundle_identifier** and **environment → vars → BUNDLE_ID**. The build script copies that ID and the team ID into Godot’s export preset.

## 2. Push the project to GitHub

Create an empty private repository called `elemental-td` on GitHub. Leave the README, license, and .gitignore options unchecked when creating it so the first push can use the local history.

In PowerShell, run the following commands from anywhere inside the local Elemental TD checkout, including its `tools` folder. The first line takes you to the project root, where `project.godot` and `.gitignore` live.

```powershell
Set-Location -LiteralPath (git rev-parse --show-toplevel)
git add -- .gitignore project.godot codemagic.yaml export_presets.cfg assets data scenes scripts tests tools docs
git status --short
```

An `A` in the first column means a new file is staged. If you see `pathspec '.gitignore' did not match any files`, check that the prompt is at the project root before rerunning `git add`. Git for Windows may warn that LF will be replaced by CRLF in the working copy. The warning describes local line-ending conversion. If `git status --short` shows the expected staged files, continue. [Git line-ending configuration](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)

For the first push, replace `YOUR_ACCOUNT` with your GitHub username or organization, or use the HTTPS URL GitHub shows for the repository. If `git remote -v` already lists the correct `origin`, skip the `git remote add` line.

```powershell
git commit -m "Prepare Elemental TD for TestFlight"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/elemental-td.git
git push -u origin main
```

## 3. Connect Codemagic and configure signing

1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API** and generate a **Team Key** with the **App Manager** role. Download the `.p8` file and copy the **Key ID** and **Issuer ID**. Keep the private key out of the GitHub repository.
2. In Codemagic, open **Team integrations → Developer Portal → Manage keys**. Add those three values and name the integration `elementaltower-ios` to match the workflow.
3. Under **Code signing identities** in Codemagic, make an **Apple Distribution** certificate with its private key available to the team. Fetch or upload the matching **App Store** provisioning profile for your bundle ID. [Codemagic iOS signing setup](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
4. In Codemagic, add the app from your GitHub repository and grant it access to the repo. In the app’s environment variables, add `APPLE_TEAM_ID` to a group named `ios_settings`. Use the 10-character Team ID from Apple Developer membership.

## 4. Build and install

1. In Codemagic, click **Start new build**, select the `main` branch and **Elemental TD iOS TestFlight** workflow, and start the build.
2. After it succeeds, the signed `.ipa` is in **Artifacts**. The workflow also uploads the build to App Store Connect. [Codemagic App Store Connect publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
3. Once processing finishes, open **TestFlight** for the app in App Store Connect, add the build to an internal testing group, and invite your Apple account. Accept the invitation and install the game in the **TestFlight** app on the iPhone. [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)

The first iPhone build should check portrait and landscape rotation, safe areas, touch input, haptics, background and resume behavior, and performance during large waves.
