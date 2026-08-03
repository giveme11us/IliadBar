cask "iliadbar" do
  version :latest
  sha256 :no_check

  url "https://github.com/giveme11us/IliadBar/releases/latest/download/IliadBar.zip"
  name "IliadBar"
  desc "Native macOS menu-bar control center for iliadbox"
  homepage "https://github.com/giveme11us/IliadBar"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "IliadBar.app"
  binary "#{appdir}/IliadBar.app/Contents/MacOS/ibx"

  zap trash: [
    "~/Library/Application Support/IliadBar",
    "~/Library/Application Scripts/it.ivansposato.iliadbar.widget",
    "~/Library/Containers/it.ivansposato.iliadbar.widget",
    "~/Library/Group Containers/$(TeamIdentifierPrefix)it.ivansposato.iliadbar",
    "~/Library/Preferences/it.ivansposato.iliadbar.plist",
  ]
end
