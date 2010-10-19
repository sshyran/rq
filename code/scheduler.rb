
require 'socket'
require 'json'
require 'fcntl'
require 'fileutils'
require 'code/unixrack'
require 'code/hashdir'

module RQ
  class Scheduler

    def initialize(options, parent_pipe)
      @start_time = Time.now
      # Read config
      @name = "scheduler"
      @sched_path = "scheduler/"
      @rq_config_path = "./config/"
      @parent_pipe = parent_pipe
      init_socket

      @wait_time = 1

      @config = {}

      @status = {}
      @status["admin_status"] = "UP"
      @status["oper_status"]  = "UP"


      if load_rq_config() == nil
        sleep 5
        log("Invalid main rq config. Exiting." )
        exit! 1
      end

      if load_config() == false
        sleep 5
        log("Invalid config for #{@name}. Skipping." )
        #exit! 1
      end
    end

    def self.log(path, mesg)
      File.open(path + '/sched.log', "a") do
        |f|
        f.write("#{Process.pid} - #{Time.now} - #{mesg}\n")
      end
    end

    def self.start_process(options)
      # nice pipes writeup
      # http://www.cim.mcgill.ca/~franco/OpSys-304-427/lecture-notes/node28.html
      child_rd, parent_wr = IO.pipe

      child_pid = fork do
        sched_path = "scheduler/"
        $0 = "[rq-scheduler]"
        begin
          parent_wr.close
          #child only code block
          RQ::Scheduler.log(sched_path, 'post fork')

          # Unix house keeping
          self.close_all_fds([child_rd.fileno])
          # TODO: probly some other signal, session, proc grp, etc. crap

          RQ::Scheduler.log(sched_path, 'post close_all')
          q = RQ::Scheduler.new(options, child_rd)
          # This should never return, it should Kernel.exit!
          # but we may wrap this instead
          RQ::Scheduler.log(sched_path, 'post new')
          q.run_loop
        rescue Exception
          self.log(sched_path, "Exception!")
          self.log(sched_path, $!)
          self.log(sched_path, $!.backtrace)
          raise
        end
      end

      #parent only code block
      child_rd.close

      if child_pid == nil
        parent_wr.close
        return nil
      end

      [child_pid, parent_wr]
    end

    def self.close_all_fds(exclude_fds)
      0.upto(1023) do |fd|
        begin
          next if exclude_fds.include? fd
          if io = IO::new(fd)
            io.close
          end
        rescue
        end
      end
    end

    def init_socket
      # Show pid
      File.unlink(@sched_path + '/sched.pid') rescue nil
      File.open(@sched_path + '/sched.pid', "w") do
        |f|
        f.write("#{Process.pid}\n")
      end

      # Setup IPC
      File.unlink(@sched_path + '/sched.sock') rescue nil
      @sock = UNIXServer.open(@sched_path + '/sched.sock')
    end

    def load_rq_config
      begin
        data = File.read(@rq_config_path + 'config.json')
        js_data = JSON.parse(data)
        @host = js_data['host']
        @port = js_data['port']
      rescue
        return nil
      end
      return js_data
    end

    def load_config
      begin
        data = File.read(@sched_path + '/config.json')
        @config = JSON.parse(data)
      rescue
        return false
      end
      return true
    end

    def log(mesg)
      File.open(@sched_path + '/sched.log', "a") do
        |f|
        f.write("#{Process.pid} - #{Time.now} - #{mesg}\n")
      end
    end

    def shutdown!
      log("Received shutdown")
      # TODO: proper oper status
      # write_status
      Process.exit! 0
    end

    def run_scheduler!
      @wait_time = 60

      # Look at priority queue for things to schedule
    end

    def run_loop

      Signal.trap("TERM") do
        log("received TERM signal")
        shutdown!
      end

      while true
        #run_scheduler!
        sleep 60
      end
    end

  end
end

