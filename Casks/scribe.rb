cask "scribe" do
  version "2.4.4"
  sha256 "85a9e01579fef5c85aa1c2e8bc0a6da3adf34ecd20dca513dedc4747e83dc05e"

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
