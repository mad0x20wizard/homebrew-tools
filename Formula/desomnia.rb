class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.0.0-alpha52.tar.gz"
  sha256 "ca51b116eb3be9610b565d1212e3fda9827f455997a9781588e883d91aea60de"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "e5bb0cc23d3ff2e4b00ef2d7cdf6608166ec2868b8d8e0648cc6975277c52be1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "600511e8bfe4ee74842175e8a7d6d60168c896b2efa3e92a6217da18ba7b2661"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "d9789d4546bea2e6e4bb168c9779d3d3158eb337751ebd49351be316f4c3b720"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "aab3fcace65df83ef5b2eb266b9efa5dd18dfd16c31a24976b20faf16891df8f"
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
