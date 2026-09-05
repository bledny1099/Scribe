cask "scribe" do
  version "2.6.2"
  sha256 "c261f33ccb513180234b03c8e2ddcf7da0ee88b583b936c69c2b45acdee9b076"

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
