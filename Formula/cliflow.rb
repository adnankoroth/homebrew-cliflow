# Homebrew Formula for CLIFlow
# 
# Installation:
#   brew tap adnankoroth/cliflow
#   brew install cliflow
#
# Or directly:
#   brew install adnankoroth/cliflow/cliflow

class Cliflow < Formula
  desc "IDE-style terminal autocompletion for 800+ CLI tools - offline, privacy-first"
  homepage "https://github.com/adnankoroth/cliflow"
  url "https://github.com/adnankoroth/cliflow/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "1b1d2a56c26858ba24a41e109aa6dd95d0c586f27ffd8fa138f6cfe8f10ed5b6"
  license "MIT"
  head "https://github.com/adnankoroth/cliflow.git", branch: "main"

  depends_on "node"

  def install
    # Install npm dependencies
    system "npm", "ci", "--ignore-scripts"
    
    # Build the project
    system "npm", "run", "build"
    
    # Install to libexec (keeps node_modules isolated)
    libexec.install "build"
    libexec.install "package.json"
    
    # Install shell integration files using system cp
    shell_dir = share/"cliflow/shell-integration"
    shell_dir.mkpath
    cp "shell-integration/cliflow.zsh", shell_dir
    cp "shell-integration/cliflow.bash", shell_dir
    cp "shell-integration/cliflow.fish", shell_dir
    cp "shell-integration/client.mjs", shell_dir
    
    # Create main CLI wrapper
    (bin/"cliflow").write <<~EOS
      #!/bin/bash
      export CLIFLOW_HOME="${CLIFLOW_HOME:-$HOME/.cliflow}"
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/build/bin/cliflow.js" "$@"
    EOS

    # Create daemon wrapper
    (bin/"cliflow-daemon").write <<~EOS
      #!/bin/bash
      export CLIFLOW_HOME="${CLIFLOW_HOME:-$HOME/.cliflow}"
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/build/daemon/server.js" "$@"
    EOS

    # Install completions (copy from source, not shell_dir, since install moves files)
    zsh_completion.install "shell-integration/cliflow.zsh" => "_cliflow"
    bash_completion.install "shell-integration/cliflow.bash" => "cliflow"
  end

  def post_install
    # Note: ~/.cliflow is created automatically by shell integration on first load
    (var/"cliflow").mkpath
  end

  def caveats
    <<~EOS
      #{Tty.bold}CLIFlow has been installed!#{Tty.reset}

      #{Tty.bold}Quick Setup:#{Tty.reset}
        cliflow setup

      #{Tty.bold}Or manual setup - add to your shell config:#{Tty.reset}

        #{Tty.underline}Zsh (~/.zshrc):#{Tty.reset}
          source "#{share}/cliflow/shell-integration/cliflow.zsh"

        #{Tty.underline}Bash (~/.bashrc):#{Tty.reset}
          source "#{share}/cliflow/shell-integration/cliflow.bash"

      #{Tty.bold}Then:#{Tty.reset}
        1. Restart your terminal (or source your config)
        2. The daemon starts automatically when you open a new terminal

      #{Tty.bold}Verify:#{Tty.reset}
        cliflow status
        
      #{Tty.bold}To start daemon manually:#{Tty.reset}
        brew services start cliflow
    EOS
  end

  service do
    run [opt_bin/"cliflow-daemon", "start"]
    keep_alive true
    working_dir var/"cliflow"
    log_path var/"log/cliflow.log"
    error_log_path var/"log/cliflow.log"
  end

  test do
    assert_match "CLIFlow", shell_output("#{bin}/cliflow --help")
    assert_match version.to_s, shell_output("#{bin}/cliflow --version")
  end
end
