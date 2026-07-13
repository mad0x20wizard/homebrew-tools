class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.1.0-alpha17.tar.gz"
  sha256 "e2650e2ee8ce247193e5b866118a919f2530d5c9c460ab597ad9f2f32377363a"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any, arm64_tahoe:   "84dcfd295f233f8bae027c4141548f8258586662ad4e62086cfd8c412c27a992"
    sha256 cellar: :any, arm64_sequoia: "b6487e51af9ecb0a6588569b9a7d33cb9b3c471d76831578c3c404361ee1ac0f"
    sha256 cellar: :any, arm64_linux:   "76d0f0db6c24e6efd2e417746f8fc822573da583596c486070848de8318c1c49"
    sha256               x86_64_linux:  "ba250c1e3b56082496c8add0991101c9d5c61bf242b62a5931560f0318c554a3"
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

  post_install_steps do
    mkdir_p "desomnia", base: :etc
    mkdir_p "log/desomnia", base: :var
    mkdir_p "lib/desomnia/plugins", base: :var
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
