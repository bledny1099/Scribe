cask "scribe" do
  version "2.6.3"
  sha256 "87c7eca107a4dbd4ca19fec3fe0aac6e4c711788128ab8ba6a7dd7ffbc8afd89"

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
