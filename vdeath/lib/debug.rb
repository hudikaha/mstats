require 'logger'

Log = Logger.new(STDERR)
Log.formatter = proc do |severity, datetime, progname, msg|
    if severity == 'INFO'
        "#{msg}\n"
    else
        "#{severity[0]} #{msg}\n"
    end
end

Log.level = Logger::INFO
