require 'logger'

class Log
  @@log_file = nil

  def Log.initialize(log_file)
    @@log_file = log_file
    @@log = Logger.new(log_file, 'daily')
  end

  def Log.log_file
    @@log_file
  end

  def Log.info(text)
    puts text
    @@log.info(text)
  end

  def Log.warn(text)
    puts text
    @@log.warn(text)
  end

  def Log.error(text)
    puts text
    @@log.error(text)
  end
end