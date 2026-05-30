class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.0.0-beta11.tar.gz"
  sha256 "8ad57b7cda6bf2b8aa0acaa6606cd3d475e62d314327c3196afcb44e9d15342e"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "46ffb25afdb1e0d5d88f4a8dc467f91f6d4f0cfa70eb94178775e63658c6536d"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "975c3e7e22fa09f8f089e7b5aa80c74b420c083c081c31123b2d41b0a37d7d5c"
    sha256 cellar: :any,                 arm64_linux:   "7fc295a834a04224c29761854fe5968403dd84b8eb19de572cade521a3db1665"
    sha256 cellar: :any,                 x86_64_linux:  "6a1e320e474ec3bc7e1ddb6dbf43c2100edabfefb411a3603d7985083276e2d6"
  end

  depends_on "dotnet" => [:build]
  depends_on "brotli"
  depends_on "icu4c"

  uses_from_macos "libpcap"

  on_linux do
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

    install_plugins ["FirewallKnockOperator"]
  end

  def install_plugins(plugins)
    plugins.each do |plugin_name|
      target = buildpath/"publish/plugins/#{plugin_name}"

      system "dotnet", "publish", "plugins/#{plugin_name}/#{plugin_name}.csproj",
              "-c", "Release",
              "--no-self-contained",
              "-p:DebugType=None",
              "-p:DebugSymbols=false",
              "-p:PublishSingleFile=false",
              "-o", target

      (libexec/"plugins"/plugin_name).install Dir[target/"*"]
    end
  end

  def post_install
    (etc/"desomnia").mkpath
    (var/"log/desomnia").mkpath
    (var/"lib/desomnia/plugins").mkpath
  end

  test do
    # system bin"/desomniad", "--version" // TODO: Implement testing
    assert_match "Hello, World!", "Hello, World!"
  end

  service do
    name macos: "de.madwizard.Desomnia",
         linux: "desomnia"
    run [opt_bin/"desomniad"]
    require_root true
    keep_alive crashed: true
    process_type :background
    working_dir var

    environment_variables DESOMNIA_CONFIG_DIR:       etc/"desomnia",
                          DESOMNIA_LOG_DIR:          var/"log/desomnia",
                          DESOMNIA_USER_PLUGINS_DIR: var/"lib/desomnia/plugins",
                          DESOMNIA_CORE_PLUGINS_DIR: opt_libexec/"plugins"

    if OS.mac?
      log_path var/"log/desomnia/output.log"
      error_log_path var/"log/desomnia/error.log"
    end
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
