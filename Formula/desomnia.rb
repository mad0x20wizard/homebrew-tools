class Desomnia < Formula
  desc "Desomnia monitor"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  license "MIT" # <- change if needed
  
  url "https://github.com/mad0x20wizard/Desomnia/releases/download/v3.0.0-alpha22/Desomnia_3.0.0-alpha22_macos.zip"
  sha256 "e620f3f5d213e68735609c6e20c3994c17017b25ac8f4c35626e578d81e4e9b7"

  def install
    arch_dir = Hardware::CPU.arm? ? "arm64" : "x64"

    bin.install "#{arch_dir}/desomniad"

    (etc/"desomnia").mkpath
    (var/"log/desomnia").mkpath
  end

  service do
    name macos: "de.madwizard.Desomnia"
    run [opt_bin/"desomniad"]
    require_root true
    keep_alive true
    process_type :background
    working_dir var

    log_path var/"log/desomnia/output.log"
    error_log_path var/"log/desomnia/error.log"
  end

  test do
    #system bin"/desomniad", "--version"
  end
end