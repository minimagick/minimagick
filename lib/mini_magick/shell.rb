require "timeout"
require "benchmark"

module MiniMagick
  ##
  # Sends commands to the shell (more precisely, it sends commands directly to
  # the operating system).
  #
  # @private
  #
  class Shell

    def run(command, options = {})
      stdout, stderr, status = execute(command, stdin: options[:stdin])

      if status != 0 && options.fetch(:whiny, MiniMagick.whiny)
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with status: #{status} and error:\n#{stderr}"
      end

      $stderr.print(stderr) unless options[:stderr] == false

      [stdout, stderr, status]
    end

    def execute(command, options = {})
      stdout, stderr, status =
        log(command.join(" ")) do
          send("execute_#{MiniMagick.shell_api.tr("-", "_")}", command, options)
        end

      [stdout, stderr, status.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    private

    class P_FinishWrite < ::StandardError
    end

    P_ChunkSize = 1024 * 32

    private_constant :P_FinishWrite, :P_ChunkSize

    def execute_open3(command, options = {})
      require "open3"
      # We would ideally use Open3.capture3, but it wouldn't allow us to
      # terminate the command after timing out.

      out_buffer, err_buffer = [::StringIO.new, ::StringIO.new]
      start_time = ::Time.now
      applied_timeout = MiniMagick.timeout || 3_600
      ::Open3.popen3(*command) do |in_w, out_r, err_r, thread|
        [in_w, out_r, err_r, out_buffer, err_buffer].each(&:binmode)
        read_wait, write_wait = [[out_r, err_r], [in_w]]
        stdin_buffer = options[:stdin].to_s
        if stdin_buffer.empty?
          in_w.close
          write_wait.delete(in_w)
        end
        until read_wait.empty? && write_wait.empty? do
          current_time = ::Time.now
          elapse = current_time - start_time
          remaining = applied_timeout - elapse
          raise Timeout::Error, "MiniMagick command timed out: #{command}" unless 0 < remaining
          readable, writable = ::IO.select(read_wait, write_wait, read_wait + write_wait, remaining)
          writable&.each do |io|
            # assume io == in_w
            byte_written = io.write_nonblock stdin_buffer
            stdin_buffer = begin
              stdin_buffer.byteslice(byte_written..-1)
            rescue ::NoMethodError
              stdin_buffer.slice(byte_written..-1)
            end
            raise P_FinishWrite unless 0 < stdin_buffer.bytesize
          rescue ::Errno::EAGAIN, ::Errno::EINTR
            next
          rescue ::Errno::EPIPE, P_FinishWrite
            io.close
            write_wait.delete(io)
          end
          readable&.each do |io|
            buffer = io.read_nonblock(P_ChunkSize)
            out_buffer << buffer if io == out_r
            err_buffer << buffer if io == err_r
          rescue ::Errno::EAGAIN, ::Errno::EINTR
            next
          rescue ::EOFError
            io.close
            read_wait.delete(io)
          end
        end
        [out_buffer.string, err_buffer.string, thread.value]
      end
    end

    def execute_posix_spawn(command, options = {})
      require "posix-spawn"
      child = POSIX::Spawn::Child.new(*command, input: options[:stdin].to_s, timeout: MiniMagick.timeout)
      [child.out, child.err, child.status]
    rescue POSIX::Spawn::TimeoutExceeded
      raise Timeout::Error, "MiniMagick command timed out: #{command}"
    end

    def log(command, &block)
      value = nil
      duration = Benchmark.realtime { value = block.call }
      MiniMagick.logger.debug "[%.2fs] %s" % [duration, command]
      value
    end

  end
end
