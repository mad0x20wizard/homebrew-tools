class Desomnia < Formula
  desc "Desomnia monitor"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  license "MIT" # <- change if needed
  
  url "https://github.com/mad0x20wizard/Desomnia-Test/releases/download/v3.0.0-beta10/Desomnia_3.0.0-beta10_macos.zip"
  sha256 "6c2204108ee8a7e81593e2787383b32b1605962c0cb14b02019e34f0c8df24eb"

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