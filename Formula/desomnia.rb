class Desomnia < Formula
  desc "Desomnia monitor"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  license "MIT" # <- change if needed
  
  url "https://github.com/mad0x20wizard/Desomnia-Test/releases/download/v3.0.0-beta11/Desomnia_3.0.0-beta11_macos.zip"
  sha256 "57e71a27bd95f3cf89a6abccb77ca2f50f84392938f0df2605b65425f9e370b9"

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