cask "scribe" do
  version "2.6.1"
  sha256 "1f1a0e36dac1343bf438ff860d9e045105ed0afd0fefa08c2db45a4f48848b1c"

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
