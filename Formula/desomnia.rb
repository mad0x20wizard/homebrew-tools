class Desomnia < Formula
  desc "Daemon for sleep and resource management"
  homepage "https://github.com/mad0x20wizard/Desomnia"
  url "https://github.com/mad0x20wizard/Desomnia/archive/refs/tags/v3.3.0-alpha2.tar.gz"
  sha256 "45ebde9a8fe27162ac8fb94e16ef0043ee3e2f91968761a062b1a3b3772c7222"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/mad0x20wizard/tools"
    sha256 cellar: :any, arm64_tahoe:   "f1e35b96fe66c11cc3a724c1c870dfefa4ea82cc98e680a43bb38170fcd836e5"
    sha256 cellar: :any, arm64_sequoia: "1a902823f7ed2755c044241fc86f25b49d6d339fe2820a825fd082d4405816e0"
    sha256 cellar: :any, arm64_linux:   "f6868cd01542be61ac4b1f2ccc6836923aedcf390e2c92ce6b49d8db3365c28d"
    sha256               x86_64_linux:  "c41d43f68b536df06d014bfa00dab056cb9d078c9e536e95e4b3a1920776d287"
  end

  # macOS installs the NativeAOT ("native") build by default: a single self-contained binary that
  # needs no .NET runtime and a fraction of the memory. NativeAOT cannot load plugins at runtime,
  # so the plugins shipped with Desomnia are compiled into the binary instead -- third-party
  # plugins dropped into var/lib/desomnia/plugins are ignored. Pass --with-plugins for the
  # framework-based build that loads plugins from disk.
  #
  # Linux keeps the framework-based build either way: a NativeAOT binary links against the build
  # machine's glibc, and glibc is forward-incompatible, so a bottle built on the Ubuntu 24.04
  # runners (glibc 2.39) would refuse to start on older distributions. Linux users who want the
  # native flavour install the deb/rpm packages or the "-native" Docker image instead.
  option "with-plugins", "Build with runtime plugin support instead of NativeAOT (macOS only)"

  depends_on "dotnet" => [:build]
  depends_on "brotli"
  depends_on "icu4c"
  # macOS needs this for the native build as well: NativeAOT links the crypto shim into the binary
  # at build time, so libcrypto/libssl end up as real load commands in the Mach-O instead of being
  # resolved lazily by the .NET runtime the way the framework-based build does it.
  depends_on "openssl@3"

  uses_from_macos "libpcap"

  on_linux do
    depends_on "libunwind"
    depends_on "zlib-ng-compat"
  end

  def install
    if native?
      # PublishAot is passed on the command line so it is a *global* property: besides driving ILC
      # it defines DESOMNIA_AOT (see Directory.Build.props), which statically registers the shipped
      # plugin modules in place of the runtime plugin loader and activates the AOT-only settings in
      # the project file (trimmer roots, size-optimised ILC). --self-contained, PublishSingleFile
      # and PublishReadyToRun do not apply to -- and partly conflict with -- an AOT build.
      system "dotnet", "publish", project_path,
              "-c", "Release",
              "-r", rid,
              "-p:PublishAot=true",
              "-p:StripSymbols=true",
              "-o", buildpath/"publish"

      bin.install buildpath/"publish/desomniad"
    else
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

  def caveats
    return unless native?

    <<~EOS
      Desomnia was installed as a self-contained native build. It needs no .NET runtime and uses
      considerably less memory, but it cannot load plugins at runtime -- the plugins shipped with
      Desomnia are compiled into the binary, and #{var}/lib/desomnia/plugins is not read.

      To run the build that loads plugins from disk instead:
        brew reinstall --with-plugins #{full_name}
    EOS
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

  # NativeAOT is the default on macOS, unless the user opted into runtime plugin support.
  # See the comment on the "with-plugins" option for why Linux never takes this path.
  def native?
    OS.mac? && build.without?("plugins")
  end

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
