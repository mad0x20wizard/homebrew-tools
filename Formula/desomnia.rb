class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.2.3.tar.gz"
  sha256 "2722d6d580ae0c06059c9860acafd9624742af15fb6f6d5fadc15776f17d4644"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any, arm64_tahoe:   "f1e35b96fe66c11cc3a724c1c870dfefa4ea82cc98e680a43bb38170fcd836e5"
    sha256 cellar: :any, arm64_sequoia: "1a902823f7ed2755c044241fc86f25b49d6d339fe2820a825fd082d4405816e0"
    sha256 cellar: :any, arm64_linux:   "f6868cd01542be61ac4b1f2ccc6836923aedcf390e2c92ce6b49d8db3365c28d"
    sha256               x86_64_linux:  "c41d43f68b536df06d014bfa00dab056cb9d078c9e536e95e4b3a1920776d287"
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
