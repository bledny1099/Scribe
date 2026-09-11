cask "scribe" do
  version "2.6.9"
  sha256 "50393ae6ee7e0aa186214723593183099545d3e50dcd55227ee26659d472fa97"

  url "https://github.com/bledny1099/Scribe/releases/download/v#{version}/Scribe.dmg"
  name "Scribe"
  desc "Fast, private, customizable, open-source dictation for macOS"
  homepage "https://github.com/bledny1099/Scribe"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Scribe.app"

  zap trash: [
    "~/Library/Application Support/com.aleksei.scribe",
    "~/Library/Caches/com.aleksei.scribe",
    "~/Library/Preferences/com.aleksei.scribe.plist",
  ]
end
