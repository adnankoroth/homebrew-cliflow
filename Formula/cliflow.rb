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
  url "https://github.com/adnankoroth/cliflow/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "3e84fa1473fd291cde0bd2f2b09302e45fb62d5e9b07baaf792e07ae4466d78b"
  license "MIT"
  head "https://github.com/adnankoroth/cliflow.git", branch: "main"

  depends_on "node@20"

  def install
    # Install npm dependencies
    system "npm", "ci", "--ignore-scripts"
    
    # Build the project
    system "npm", "run", "build"
    
    # Install to libexec (keeps node_modules isolated)
    libexec.install "build"
    libexec.install "shell-integration"
    libexec.install "package.json"
    
    # Create main CLI wrapper
    (bin/"cliflow").write <<~EOS
      #!/bin/bash
      export CLIFLOW_HOME="${CLIFLOW_HOME:-$HOME/.cliflow}"
      exec "#{Formula["node@20"].opt_bin}/node" "#{libexec}/build/bin/cliflow.js" "$@"
    EOS

    # Create daemon wrapper
    (bin/"cliflow-daemon").write <<~EOS
      #!/bin/bash
      export CLIFLOW_HOME="${CLIFLOW_HOME:-$HOME/.cliflow}"
      exec "#{Formula["node@20"].opt_bin}/node" "#{libexec}/build/daemon/server.js" "$@"
    EOS

    # Install shell integration files to share
    (share/"cliflow").install "shell-integration"
    
    # Install zsh completions
    zsh_completion.install "shell-integration/cliflow.zsh" => "_cliflow"
    
    # Install bash completions  
    bash_completion.install "shell-integration/cliflow.bash" => "cliflow"
  end

  def post_install
    # Create CLIFLOW_HOME directory
    (var/"cliflow").mkpath
    
    # Create symlink for shell integration
    cliflow_home = Pathname.new(ENV["HOME"])/".cliflow"
    unless cliflow_home.exist?
      cliflow_home.mkpath
      (cliflow_home/"shell-integration").make_symlink(share/"cliflow/shell-integration")
    end
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
