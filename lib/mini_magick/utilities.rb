require 'rbconfig'

module MiniMagick
  module Utilities
    class << self
      # Cross-platform way of finding an executable in the $PATH.
      #
      #   which('ruby') #=> /usr/bin/ruby
      def which(cmd)
        exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          end
        end
        nil
      end

      # Finds out if the host OS is windows
      def windows?
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      end

      def windows_escape(value)
        # For Windows, ^ is the escape char, equivalent to \ in Unix.
        escaped = value.gsub(/\^/, '^^').gsub(/>/, '^>')
        if escaped !~ /^".+"$/ && escaped.include?("'")
          escaped.inspect
        else
          escaped
        end
      end
    end
  end
end
