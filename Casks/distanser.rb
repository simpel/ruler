cask "distanser" do
  version "1.6.0"
  sha256 "11adcc1479ec7db3dabe07309d3c09105e142cada9fe1e6e2efbbbd07a757724"

  url "https://github.com/simpel/ruler/releases/download/v#{version}/Distanser-#{version}.dmg"
  name "Distanser"
  desc "Screen ruler overlay with live cursor readout, guides and drag measuring"
  homepage "https://www.joelsanden.se/ruler/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Distanser.app"

  zap trash: [
    "~/Library/Preferences/se.joelsanden.ruler.plist",
    "~/Library/Saved Application State/se.joelsanden.ruler.savedState",
  ]

  caveats <<~EOS
    Distanser is not signed with an Apple Developer ID, so macOS quarantines it.
    The first launch will be blocked; clear the flag once with

      xattr -dr com.apple.quarantine #{appdir}/Distanser.app

    or open it from System Settings -> Privacy & Security -> Open Anyway.
  EOS
end
