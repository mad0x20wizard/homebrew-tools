class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.0.0-alpha34.tar.gz"
  sha256 "4d84aef5929d315ecd24318a6a14ca46ba2245f5a7ec40b29a1338a661238860"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "bdcf081d8d3104f7d90c6a04c314b9a57492b0dc625f663e7b0d84c4133870dd"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "6df53b21ac8ce77d5e1b154f41814dbde033010564c515cdd46d131161a31dca"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8f3f1291b0609646c8daecafe653b30f6611e3d235e6ca382f558ab49ee83ab8"
  end

  depends_on "dotnet" => [:build]
  depends_on "brotli"

  on_linux do
    depends_on "icu4c@78"
    depends_on "libunwind"
    depends_on "openssl@3"
    depends_on "zlib-ng-compat"
  end

  def install
    system "dotnet", "publish", project_path,
            "-c", "Release",
            "-r", rid,
            "--self-contained",
            "-p:DebugSymbols=false",
            "-p:PublishSingleFile=true",
            "-p:PublishReadyToRun=true",
            "-o", buildpath/"publish"

    bin.install buildpath/"publish/desomniad"

    (etc/"desomnia").mkpath
    (var/"log/desomnia").mkpath
  end

  test do
    # system bin"/desomniad", "--version"
    assert_match "Hello, World!", "Hello, World!"
  end

  service do
    name macos: "de.madwizard.Desomnia"
    run [opt_bin/"desomniad"]
    require_root true
    keep_alive crashed: true
    process_type :background
    working_dir var

    log_path var/"log/desomnia/output.log"
    error_log_path var/"log/desomnia/error.log"
  end

  private

  def project_path
    if OS.mac?
      "DesomniaLaunchDaemon/DesomniaLaunchDaemon.csproj"
    elsif OS.linux?
      "DesomniaDaemon/DesomniaDaemon.csproj"
    else
      odie "Unsupported OS for building the project"
    end
  end

  def rid
    dotnet_info = Utils.safe_popen_read("dotnet", "--info")

    rid_line = dotnet_info.lines.find do |l|
      l.start_with?(" RID:", "RID:")
    end

    odie "Could not determine .NET RID from `dotnet --info`" if rid_line.nil?

    id = rid_line.split(":", 2).last&.strip
    odie "Could not parse RID from `dotnet --info`" if id.blank?

    id
  end
end
