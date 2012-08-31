require 'socket'
require 'json'

module Zeus
  class << self

    attr_accessor :plan

    def report_error_to_master(local, error)
      str = "R:"
      str << "#{error.backtrace[0]}: #{error.message} (#{error.class})\n"
      error.backtrace[1..-1].each do |line|
        str << "\tfrom #{line}\n"
      end
      File.open("a.log","a"){|f|f.puts str}
      local.write str
    end

    def run_action(socket, identifier)
      plan.send(identifier)
      socket.write "R:OK"
    rescue Exception => e
      report_error_to_master(socket, e)
    end

    def notify_newly_loaded_files
    end

    def handle_dead_children(sock)
      # TODO: It would be nice if it were impossible for this
      # to interfere with the identifer -> IO thing.
      loop do
        pid = Process.wait(-1, Process::WNOHANG)
        break if pid.nil?
        # sock.send("D:#{pid}")
      end
    rescue Errno::ECHILD
    end

    def go(identifier=:boot)
      identifier = identifier.to_sym
      $0 = "zeus slave: #{identifier}"
      # okay, so I ahve this FD that I can use to send data to the master.
      fd = ENV['ZEUS_MASTER_FD'].to_i
      master = UNIXSocket.for_fd(fd)

      # I need to give the master a way to talk to me exclusively
      local, remote = UNIXSocket.pair(:DGRAM)
      master.send_io(remote)

      # Now I need to tell the master about my PID and ID
      local.write "P:#{Process.pid}:#{identifier}"

      # Now we run the action and report its success/fail status to the master.
      run_action(local, identifier)

      # the master wants to know about the files that running the action caused us to load.
      Thread.new { notify_newly_loaded_files }

      pid = Process.pid
      trap("CHLD") { handle_dead_children(local) if Process.pid == pid }

      # We are now 'connected'. From this point, we may receive requests to fork.
      loop do
        new_identifier = local.recv(1024)
        if new_identifier =~ /^S:/
          fork { plan.after_fork ; go(new_identifier.sub(/^S:/,'')) }
        else
          fork { plan.after_fork ; command(new_identifier.sub(/^C:/,''), local) }
        end
      end

    end

    def command(identifier, sock)
      $0 = "zeus runner: #{identifier}"
      Process.setsid

      local, remote = UNIXSocket.pair(:DGRAM)
      sock.send_io(remote)
      remote.close
      sock.close

      arguments = local.recv(1024)

      pid = fork {
        plan.after_fork
        client_terminal = local.recv_io
        local.write "P:#{Process.pid}:\n"
        local.close

        $stdin.reopen(client_terminal)
        $stdout.reopen(client_terminal)
        $stderr.reopen(client_terminal)
        ARGV.replace(JSON.parse(arguments))

        plan.send(identifier)
      }

      File.open("f.log", "a") {|f|f.puts "A"}
      Process.wait(pid)
      File.open("f.log", "a") {|f|f.puts "B"}
      code = $?.exitstatus

      local.write "#{code}\n"
      File.open("f.log", "a") {|f|f.puts "C"}
      local.close
    end

  end
end