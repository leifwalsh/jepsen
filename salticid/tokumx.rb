require 'fileutils'

role :tokumx do
  task :setup do
    sudo do
      unless (dpkg '-l').include? 'tokumx-server'
        exec! 'apt-key adv --keyserver keyserver.ubuntu.com --recv-key 505A7412'
        echo 'deb [arch=amd64] http://s3.amazonaws.com/tokumx-debs precise main', to: '/etc/apt/sources.list.d/tokumx.list'
        exec! 'apt-get update', echo: true
      end
      exec! 'apt-get install -y tokumx-server', echo: true
      sudo do
        echo File.read(__DIR__/:tokumx/'tokumx.conf').gsub('%%NODE%%', name), to: '/etc/tokumx.conf'
      end
      begin
        tokumx.start
      rescue => e
        throw unless e.message =~ /already running/
      end
    end
    
    if name == 'n1'
      log "Waiting for tokumx to become available"
      loop do
        begin
          mongo '--eval', true
          break
        rescue
          sleep 1
        end
      end
      log "Initiating replica set."
      tokumx.eval 'rs.initiate()'
      log "Waiting for replica set to initialize."
      until (mongo('--eval', 'rs.status().members[0].state') rescue '') =~ /1\Z/
        log mongo('--eval', 'rs.status().members')
        sleep 1
      end
      log "Assigning priority."
      tokumx.eval 'c = rs.conf(); c.members[0].priority = 2; rs.reconfig(c)'
      
      log "Adding members to replica set."
      tokumx.eval 'rs.add("n2")'
      tokumx.eval 'rs.add("n3")'
      tokumx.eval 'rs.add("n4")'
      tokumx.eval 'rs.add("n5")'
    end
  end

  task :nuke do
    sudo do
      tokumx.stop rescue nil
      rm '-rf', '/var/lib/tokumx/*'
    end
  end

  task :stop do
    sudo { exec! 'start-stop-daemon --stop --quiet --pidfile /var/run/tokumx.pid --retry 300 --user tokumx --exec /usr/bin/mongod', echo: true }
  end

  task :start do
    sudo { exec! 'start-stop-daemon --start --background --quiet --pidfile /var/run/tokumx.pid --make-pidfile --chuid tokumx --exec  /usr/bin/mongod -- --config /etc/tokumx.conf', echo: true }
  end

  task :restart do
    tokumx.stop
    tokumx.start
  end

  task :tail do
    tail '-F', '/var/log/tokumx/tokumx.log', echo: true
  end

  task :eval do |str|
    unless (str =~ /;/)
      str = "printjson(#{str})"
    end

    mongo '--eval', str, echo: true
  end

  task :rs_conf do
    tokumx.eval 'rs.conf()'
  end

  task :rs_status do
    tokumx.eval 'rs.status()'
  end

  task :rs_stat do
    tokumx.eval 'rs.status().members.map(function(m) { print(m.name + " " + m.stateStr + "\t" + m.lastGTID + " " + m.optimeDate); }); true'
  end

  task :deploy do
    sudo do
      echo File.read(__DIR__/:tokumx/'tokumx.conf').gsub('%%NODE%%', name), to: '/etc/tokumx.conf'
    end
    tokumx.eval 'c = rs.conf(); c.members[0].priority = 2; rs.reconfig(c);'
    tokumx.restart
  end

  task :flip do
    if name != "n1"
      tokumx.eval 'rs.stepDown(30)'
    end
  end

  task :reset do
    sudo do
      find '/var/log/tokumx/', '-iname', '*.log', '-delete'
      tokumx.restart
    end
  end

  # Grabs logfiles and data files and tars them up
  task :collect do
    d = 'tokumx-collect/' + name
    FileUtils.mkdir_p d

    # Logs
    download '/var/log/tokumx/tokumx.log', d

    # Oplogs
    #oplogs = d/:oplogs
    #FileUtils.mkdir_p oplogs
    #cd '/tmp'
    #rm '-rf', 'mongo-collect'
    #mkdir 'mongo-collect'
    #mongodump '-d', 'local', '-c', 'oplog.rs', '-o', 'mongo-collect', echo: true
    #cd 'mongo-collect/local'
    #find('*.bson').split("\n").each do |f|
    #  log oplogs
    #  download f, oplogs
    #end
    #cd '/tmp'
    #rm '-rf', 'mongo-collect'

    # Data dirs
    rb = '/var/lib/tokumx/rollback'
    if dir? rb
      FileUtils.mkdir_p "#{d}/rollback"
      find(rb, '-iname', '*.bson').split("\n").each do |f|
        download f, "#{d}/rollback"
      end
    end
  end

  task :rollbacks do
    if dir? '/var/lib/tokumx/rollback'
      find('/var/lib/tokumx/rollback/',
           '-iname', '*.bson').split("\n").each do |f|
        bsondump f, echo: true
      end
      ls '-lah', '/var/lib/tokumx/rollback', echo: true 
    end
  end
end
