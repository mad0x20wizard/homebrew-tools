class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.0.0-alpha31.tar.gz"
  sha256 "8ab10e9fe6fdfa718639d573132927d3e0252fbafeeb894e274cffa6283a1685"
  license "GPL-3.0-or-later"

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
